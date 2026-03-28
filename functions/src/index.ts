import { randomInt } from 'node:crypto';

import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import {
  FieldValue,
  Timestamp,
  getFirestore,
  type DocumentReference,
  type DocumentSnapshot,
  type Transaction,
} from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { setGlobalOptions } from 'firebase-functions/v2/options';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import {
  ACTIVE_SEASON_ID,
  APP_REGION,
  BALANCE_VERSION,
  DEFAULT_PROBLEM_COUNT,
  ELIGIBILITY_ATTEMPTS,
  LEADERBOARD_LIMIT,
  SESSION_TTL_MINUTES,
} from './config';
import { generateSessionProblems } from './mathEngine';
import { calculateBrainScore } from './scoring';

initializeApp();
setGlobalOptions({ region: APP_REGION, maxInstances: 20, memory: '256MiB' });

const db = getFirestore();

type UserProfile = {
  displayName?: string;
  schoolId?: string;
  regionCode?: string;
  role?: string;
  createdAt?: unknown;
  currentSeasonBest?: number;
  personalBestOverall?: number;
};

type RankedSessionStored = {
  uid: string;
  seasonId: string;
  level: number;
  levelBucket: string;
  seed: number;
  problemCount: number;
  balanceVersion: string;
  status: 'issued' | 'consumed';
  schoolIdSnapshot: string;
  regionCodeSnapshot: string;
  expiresAt: Timestamp;
  attemptId?: string;
};

type SubmitAnswer = {
  text?: string;
  elapsedMs?: number;
  strokeCount?: number;
  pointCount?: number;
  inkHash?: string;
};

type UpsertProfileRequest = {
  displayName?: string;
  schoolId?: string;
  regionCode?: string;
  grade?: number;
};

type PreparedAggregateState = {
  levelBucket: string;
  bestRef: DocumentReference;
  bestSnap: DocumentSnapshot;
  aggregateStates: Array<{
    scope: 'global' | 'school' | 'region';
    entityId: string;
    ref: DocumentReference;
    snap: DocumentSnapshot;
  }>;
};

function assertAuthenticated(auth: unknown): { uid: string } {
  if (!auth || typeof auth !== 'object' || !("uid" in auth)) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  return { uid: String((auth as { uid: string }).uid) };
}

function normalizeAnswer(value: string | undefined): string {
  return (value ?? '').replace(/\s+/g, '').replace(/[^\d-]/g, '');
}

function problemCountForLevel(level: number): number {
  switch (level) {
    case 1:
    case 2:
      return 10;
    case 3:
    case 4:
      return 12;
    case 5:
    case 6:
      return 14;
    case 7:
    case 8:
      return 16;
    case 9:
      return 18;
    default:
      return 20;
  }
}

function aggregateId(scope: string, entityId: string, seasonId: string, levelBucket: string): string {
  return `${seasonId}_${scope}_${entityId}_${levelBucket}`;
}

function bestId(uid: string, seasonId: string, levelBucket: string): string {
  return `${seasonId}_${uid}_${levelBucket}`;
}

async function getRequiredUserProfile(uid: string): Promise<UserProfile> {
  const userSnap = await db.collection('users').doc(uid).get();
  if (!userSnap.exists) {
    throw new HttpsError('failed-precondition', 'User profile does not exist.');
  }

  const data = userSnap.data() as UserProfile;
  if (!data.schoolId || !data.regionCode) {
    throw new HttpsError('failed-precondition', 'schoolId and regionCode are required for ranked play.');
  }

  return data;
}

async function prepareAggregateState(options: {
  tx: Transaction;
  uid: string;
  seasonId: string;
  levelBucket: string;
  schoolId: string;
  regionCode: string;
}): Promise<PreparedAggregateState> {
  const { tx, uid, seasonId, levelBucket, schoolId, regionCode } = options;
  const bestRef = db.collection('user_season_bests').doc(bestId(uid, seasonId, levelBucket));
  const schoolAggregateRef = db.collection('aggregates').doc(aggregateId('school', schoolId, seasonId, levelBucket));
  const regionAggregateRef = db.collection('aggregates').doc(aggregateId('region', regionCode, seasonId, levelBucket));
  const globalAggregateRef = db.collection('aggregates').doc(aggregateId('global', 'global', seasonId, levelBucket));

  const [bestSnap, schoolSnap, regionSnap, globalSnap] = await Promise.all([
    tx.get(bestRef),
    tx.get(schoolAggregateRef),
    tx.get(regionAggregateRef),
    tx.get(globalAggregateRef),
  ]);

  return {
    levelBucket,
    bestRef,
    bestSnap,
    aggregateStates: [
      { scope: 'school', entityId: schoolId, ref: schoolAggregateRef, snap: schoolSnap },
      { scope: 'region', entityId: regionCode, ref: regionAggregateRef, snap: regionSnap },
      { scope: 'global', entityId: 'global', ref: globalAggregateRef, snap: globalSnap },
    ],
  };
}

function applyAggregateWrites(options: {
  tx: Transaction;
  prepared: PreparedAggregateState;
  uid: string;
  seasonId: string;
  schoolId: string;
  regionCode: string;
  score: number;
  attemptId: string;
}) {
  const { tx, prepared, uid, seasonId, schoolId, regionCode, score, attemptId } = options;
  const previousBest = prepared.bestSnap.exists ? Number(prepared.bestSnap.data()?.bestBrainScore ?? 0) : 0;
  const previousAttempts = prepared.bestSnap.exists ? Number(prepared.bestSnap.data()?.qualifyingAttempts ?? 0) : 0;
  const previousEligible = previousAttempts >= ELIGIBILITY_ATTEMPTS;
  const nextAttempts = previousAttempts + 1;
  const nextEligible = nextAttempts >= ELIGIBILITY_ATTEMPTS;
  const nextBest = Math.max(previousBest, score);

  tx.set(
    prepared.bestRef,
    {
      uid,
      seasonId,
      levelBucket: prepared.levelBucket,
      schoolId,
      regionCode,
      bestBrainScore: nextBest,
      bestAttemptId: attemptId,
      qualifyingAttempts: nextAttempts,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  // Optimization: 학교/지역 평균은 제출 시점의 delta만 더해 유지하면, 리더보드 화면에서 attempt 전체를 다시 읽지 않아도 됩니다.
  for (const aggregateState of prepared.aggregateStates) {
    const previousAggregate = aggregateState.snap.exists
      ? {
          eligibleUsers: Number(aggregateState.snap.data()?.eligibleUsers ?? 0),
          sumBestBrainScore: Number(aggregateState.snap.data()?.sumBestBrainScore ?? 0),
          attemptCount: Number(aggregateState.snap.data()?.attemptCount ?? 0),
        }
      : { eligibleUsers: 0, sumBestBrainScore: 0, attemptCount: 0 };

    let nextEligibleUsers = previousAggregate.eligibleUsers;
    let nextSumBestBrainScore = previousAggregate.sumBestBrainScore;

    if (!previousEligible && nextEligible) {
      nextEligibleUsers += 1;
      nextSumBestBrainScore += nextBest;
    } else if (previousEligible && nextBest > previousBest) {
      nextSumBestBrainScore += nextBest - previousBest;
    }

    const nextAttemptCount = previousAggregate.attemptCount + 1;
    const avgBestBrainScore = nextEligibleUsers === 0 ? 0 : nextSumBestBrainScore / nextEligibleUsers;

    tx.set(
      aggregateState.ref,
      {
        scope: aggregateState.scope,
        entityId: aggregateState.entityId,
        seasonId,
        levelBucket: prepared.levelBucket,
        eligibleUsers: nextEligibleUsers,
        sumBestBrainScore: nextSumBestBrainScore,
        avgBestBrainScore,
        attemptCount: nextAttemptCount,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }
}

export const createRankedSession = onCall(async (request) => {
  const { uid } = assertAuthenticated(request.auth);
  const level = Number(request.data?.level ?? 1);
  if (!Number.isInteger(level) || level < 1 || level > 10) {
    throw new HttpsError('invalid-argument', 'level must be an integer between 1 and 10.');
  }

  const requestedProblemCount = Number(request.data?.problemCount ?? problemCountForLevel(level) ?? DEFAULT_PROBLEM_COUNT);
  if (!Number.isInteger(requestedProblemCount) || requestedProblemCount < 5 || requestedProblemCount > 30) {
    throw new HttpsError('invalid-argument', 'problemCount must be between 5 and 30.');
  }

  const profile = await getRequiredUserProfile(uid);
  const sessionRef = db.collection('ranked_sessions').doc();
  const expiresAt = Timestamp.fromMillis(Date.now() + (SESSION_TTL_MINUTES * 60 * 1000));
  const sessionDoc = {
    uid,
    seasonId: ACTIVE_SEASON_ID,
    level,
    levelBucket: `level-${level}`,
    seed: randomInt(1, 0x7fffffff),
    problemCount: requestedProblemCount,
    balanceVersion: BALANCE_VERSION,
    status: 'issued',
    schoolIdSnapshot: String(profile.schoolId),
    regionCodeSnapshot: String(profile.regionCode),
    issuedAt: FieldValue.serverTimestamp(),
    expiresAt,
  };

  await sessionRef.set(sessionDoc);

  return {
    sessionId: sessionRef.id,
    seasonId: ACTIVE_SEASON_ID,
    seed: sessionDoc.seed,
    level,
    levelBucket: sessionDoc.levelBucket,
    problemCount: requestedProblemCount,
    expiresAt: expiresAt.toMillis(),
    balanceVersion: BALANCE_VERSION,
  };
});

export const submitRankedSession = onCall(async (request) => {
  const { uid } = assertAuthenticated(request.auth);
  const sessionId = String(request.data?.sessionId ?? '');
  const answers = Array.isArray(request.data?.answers) ? (request.data.answers as SubmitAnswer[]) : [];
  if (!sessionId) {
    throw new HttpsError('invalid-argument', 'sessionId is required.');
  }

  const sessionRef = db.collection('ranked_sessions').doc(sessionId);
  const userRef = db.collection('users').doc(uid);
  const attemptRef = db.collection('attempts').doc();

  return db.runTransaction(async (tx) => {
    const [sessionSnap, userSnap] = await Promise.all([tx.get(sessionRef), tx.get(userRef)]);
    if (!sessionSnap.exists) {
      throw new HttpsError('not-found', 'Ranked session does not exist.');
    }
    if (!userSnap.exists) {
      throw new HttpsError('failed-precondition', 'User profile does not exist.');
    }

    const session = sessionSnap.data() as RankedSessionStored;
    const profile = userSnap.data() as UserProfile;

    if (session.uid !== uid) {
      throw new HttpsError('permission-denied', 'This ranked session belongs to another user.');
    }
    if (session.status !== 'issued') {
      throw new HttpsError('failed-precondition', 'This ranked session has already been submitted.');
    }
    if (session.expiresAt.toMillis() < Date.now()) {
      throw new HttpsError('deadline-exceeded', 'This ranked session has expired.');
    }
    if (!profile.schoolId || !profile.regionCode) {
      throw new HttpsError('failed-precondition', 'schoolId and regionCode are required for ranked play.');
    }
    if (answers.length !== session.problemCount) {
      throw new HttpsError('invalid-argument', 'answers length must match problemCount.');
    }

    const [levelAggregateState, allAggregateState] = await Promise.all([
      prepareAggregateState({
        tx,
        uid,
        seasonId: session.seasonId,
        levelBucket: session.levelBucket,
        schoolId: String(profile.schoolId),
        regionCode: String(profile.regionCode),
      }),
      prepareAggregateState({
        tx,
        uid,
        seasonId: session.seasonId,
        levelBucket: 'all',
        schoolId: String(profile.schoolId),
        regionCode: String(profile.regionCode),
      }),
    ]);

    const problems = generateSessionProblems(session.seed, session.level, session.problemCount);
    const perProblem = problems.map((problem, index) => {
      const answer = answers[index] ?? {};
      const elapsedMs = Math.min(99999, Math.max(250, Number(answer.elapsedMs ?? 0)));
      const normalizedAnswer = normalizeAnswer(answer.text);
      return {
        i: index,
        ok: normalizedAnswer === String(problem.answer),
        ms: elapsedMs,
        recognized: normalizedAnswer,
        expected: String(problem.answer),
      };
    });

    const score = calculateBrainScore(
      session.level,
      perProblem.map((item) => ({ correct: item.ok, elapsedMs: item.ms })),
    );

    tx.set(attemptRef, {
      uid,
      sessionId,
      seasonId: session.seasonId,
      level: session.level,
      levelBucket: session.levelBucket,
      brainScore: score.brainScore,
      accuracyRate: score.accuracyRate,
      speedRate: score.speedRate,
      comboMax: score.comboMax,
      comboBonus: score.comboBonus,
      correctCount: score.correctCount,
      problemStats: perProblem,
      recognizedSummary: {
        strokeCount: answers.reduce((sum, answer) => sum + Number(answer.strokeCount ?? 0), 0),
        pointCount: answers.reduce((sum, answer) => sum + Number(answer.pointCount ?? 0), 0),
        inkHashes: answers.map((answer) => answer.inkHash).filter(Boolean),
      },
      schoolIdSnapshot: profile.schoolId,
      regionCodeSnapshot: profile.regionCode,
      submittedAt: FieldValue.serverTimestamp(),
    });

    applyAggregateWrites({
      tx,
      prepared: levelAggregateState,
      uid,
      seasonId: session.seasonId,
      schoolId: String(profile.schoolId),
      regionCode: String(profile.regionCode),
      score: score.brainScore,
      attemptId: attemptRef.id,
    });

    applyAggregateWrites({
      tx,
      prepared: allAggregateState,
      uid,
      seasonId: session.seasonId,
      schoolId: String(profile.schoolId),
      regionCode: String(profile.regionCode),
      score: score.brainScore,
      attemptId: attemptRef.id,
    });

    tx.set(
      sessionRef,
      {
        status: 'consumed',
        attemptId: attemptRef.id,
        consumedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    tx.set(
      userRef,
      {
        currentSeasonBest: Math.max(Number(profile.currentSeasonBest ?? 0), score.brainScore),
        personalBestOverall: Math.max(Number(profile.personalBestOverall ?? 0), score.brainScore),
        lastSeenAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return {
      attemptId: attemptRef.id,
      brainScore: score.brainScore,
      accuracyRate: score.accuracyRate,
      comboMax: score.comboMax,
      correctCount: score.correctCount,
    };
  });
});

export const syncUserClaims = onCall(async (request) => {
  const { uid } = assertAuthenticated(request.auth);
  const profile = await getRequiredUserProfile(uid);

  await getAuth().setCustomUserClaims(uid, {
    schoolId: profile.schoolId,
    regionCode: profile.regionCode,
    role: profile.role ?? 'player',
  });

  return {
    ok: true,
    schoolId: profile.schoolId,
    regionCode: profile.regionCode,
  };
});

export const upsertPlayerProfile = onCall(async (request) => {
  const { uid } = assertAuthenticated(request.auth);
  const input = (request.data ?? {}) as UpsertProfileRequest;
  const displayName = String(input.displayName ?? '').trim();
  const schoolId = String(input.schoolId ?? '').trim();
  const regionCode = String(input.regionCode ?? '').trim();
  const grade = Number(input.grade ?? 0);

  if (displayName.length < 2) {
    throw new HttpsError('invalid-argument', 'displayName must be at least 2 characters.');
  }
  if (!schoolId) {
    throw new HttpsError('invalid-argument', 'schoolId is required.');
  }
  if (!regionCode) {
    throw new HttpsError('invalid-argument', 'regionCode is required.');
  }
  if (!Number.isInteger(grade) || grade < 1 || grade > 6) {
    throw new HttpsError('invalid-argument', 'grade must be an integer between 1 and 6.');
  }

  const userRef = db.collection('users').doc(uid);
  const snapshot = await userRef.get();
  const existing = snapshot.exists ? (snapshot.data() as UserProfile) : undefined;

  await userRef.set(
    {
      displayName,
      schoolId,
      regionCode,
      grade,
      role: existing?.role ?? 'player',
      createdAt: existing?.createdAt ?? FieldValue.serverTimestamp(),
      lastSeenAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await getAuth().setCustomUserClaims(uid, {
    schoolId,
    regionCode,
    role: existing?.role ?? 'player',
  });

  return {
    uid,
    displayName,
    schoolId,
    regionCode,
    grade,
  };
});

export const rebuildLeaderboardSnapshots = onSchedule('every 15 minutes', async () => {
  for (const scope of ['global', 'school', 'region'] as const) {
    const snapshotId = `${ACTIVE_SEASON_ID}_${scope}_all_latest`;
    const snapshotRef = db.collection('leaderboard_snapshots').doc(snapshotId);
    const query = db
      .collection('aggregates')
      .where('seasonId', '==', ACTIVE_SEASON_ID)
      .where('scope', '==', scope)
      .where('levelBucket', '==', 'all')
      .orderBy('avgBestBrainScore', 'desc')
      .limit(LEADERBOARD_LIMIT);

    const aggregateSnap = await query.get();
    const batch = db.batch();
    batch.set(snapshotRef, {
      generatedAt: FieldValue.serverTimestamp(),
      snapshotId,
      seasonId: ACTIVE_SEASON_ID,
      scope,
      levelBucket: 'all',
      entryCount: aggregateSnap.size,
    });

    aggregateSnap.docs.forEach((doc, index) => {
      const data = doc.data();
      batch.set(snapshotRef.collection('entries').doc(String(data.entityId)), {
        rank: index + 1,
        entityId: data.entityId,
        score: data.avgBestBrainScore,
        eligibleUsers: data.eligibleUsers,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    await batch.commit();
  }
});




