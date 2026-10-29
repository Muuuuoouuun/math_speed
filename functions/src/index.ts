import { randomInt } from 'node:crypto';

import { getApps, initializeApp } from 'firebase-admin/app';
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
  TIME_ATTACK_BALANCE_VERSION,
  TIME_ATTACK_ALL_BUCKET,
  TIME_ATTACK_SESSION_TTL_MINUTES,
  MAX_ANSWERS_PER_ROUND,
  MAX_TIME_ATTACK_ROUND_MS,
  TIMEOUT_GRACE_MS,
  SUBMIT_LATENCY_SLACK_MS,
  CLOCK_SKEW_SLACK_MS,
} from './config';
import { normalizeAnswer } from './answers';
import { generateSessionProblems } from './mathEngine';
import { calculateBrainScore } from './scoring';
import { clampElapsed, isGameMode, replayRound, type GameMode } from './gameEngine';

if (getApps().length === 0) initializeApp();
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
  timeAttackSeasonBest?: number;
  timeAttackBestOverall?: number;
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
  submissionResult?: RankedSubmissionResult;
};

type RankedSubmissionResult = {
  attemptId: string;
  brainScore: number;
  accuracyRate: number;
  comboMax: number;
  correctCount: number;
};

type TimeAttackSubmissionResult = RankedSubmissionResult & {
  attemptCount: number;
  seasonBest: number;
  isNewBest: boolean;
  flagged: boolean;
};

type TimeAttackSessionStored = {
  uid: string;
  seasonId: string;
  sessionType: 'time-attack-v2';
  mode: GameMode;
  levelBucket: string;
  seed: number;
  balanceVersion: string;
  status: 'issued' | 'consumed';
  schoolIdSnapshot: string;
  regionCodeSnapshot: string;
  issuedAt: Timestamp;
  expiresAt: Timestamp;
  attemptId?: string;
  submissionResult?: TimeAttackSubmissionResult;
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
  const improved = !prepared.bestSnap.exists || score > previousBest;

  tx.set(
    prepared.bestRef,
    {
      uid,
      seasonId,
      levelBucket: prepared.levelBucket,
      schoolId,
      regionCode,
      bestBrainScore: nextBest,
      ...(improved ? { bestAttemptId: attemptId } : {}),
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

  const problemCount = Number(request.data?.problemCount ?? problemCountForLevel(level) ?? DEFAULT_PROBLEM_COUNT);
  if (!Number.isInteger(problemCount) || problemCount < 5 || problemCount > 30) {
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
    problemCount,
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
    problemCount,
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
    if (session.balanceVersion !== BALANCE_VERSION || !Number.isInteger(session.level)) {
      throw new HttpsError('failed-precondition', 'This session is not a level-based ranked session.');
    }
    if (session.status === 'consumed' && session.submissionResult) {
      return session.submissionResult;
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
      const elapsedMs = clampElapsed(answer.elapsedMs ?? 0);
      const normalizedAnswer = normalizeAnswer(String(answer.text ?? ''));
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

    const submissionResult: RankedSubmissionResult = {
      attemptId: attemptRef.id,
      brainScore: score.brainScore,
      accuracyRate: score.accuracyRate,
      comboMax: score.comboMax,
      correctCount: score.correctCount,
    };

    tx.set(
      sessionRef,
      {
        status: 'consumed',
        attemptId: attemptRef.id,
        submissionResult,
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

    return submissionResult;
  });
});

export const createTimeAttackSessionV2 = onCall(async (request) => {
  const { uid } = assertAuthenticated(request.auth);
  const mode = request.data?.mode;
  if (!isGameMode(mode)) {
    throw new HttpsError('invalid-argument', 'mode must be one of the supported game modes.');
  }

  const profile = await getRequiredUserProfile(uid);
  const sessionRef = db.collection('ranked_sessions').doc();
  const issuedAt = Timestamp.now();
  const expiresAt = Timestamp.fromMillis(issuedAt.toMillis() + TIME_ATTACK_SESSION_TTL_MINUTES * 60000);
  const sessionDoc: TimeAttackSessionStored = {
    uid,
    seasonId: ACTIVE_SEASON_ID,
    sessionType: 'time-attack-v2',
    mode,
    levelBucket: `mode-${mode}`,
    seed: randomInt(1, 0x7fffffff),
    balanceVersion: TIME_ATTACK_BALANCE_VERSION,
    status: 'issued',
    schoolIdSnapshot: String(profile.schoolId),
    regionCodeSnapshot: String(profile.regionCode),
    issuedAt,
    expiresAt,
  };
  await sessionRef.set(sessionDoc);

  return {
    sessionId: sessionRef.id,
    seasonId: sessionDoc.seasonId,
    seed: sessionDoc.seed,
    mode,
    levelBucket: sessionDoc.levelBucket,
    expiresAt: expiresAt.toMillis(),
    balanceVersion: TIME_ATTACK_BALANCE_VERSION,
    maxAnswers: MAX_ANSWERS_PER_ROUND,
    maxRoundDurationMs: MAX_TIME_ATTACK_ROUND_MS,
  };
});

export const submitTimeAttackSessionV2 = onCall(async (request) => {
  const { uid } = assertAuthenticated(request.auth);
  const sessionId = String(request.data?.sessionId ?? '');
  const answers = Array.isArray(request.data?.answers) ? request.data.answers as SubmitAnswer[] : [];
  if (!sessionId || sessionId.includes('/')) {
    throw new HttpsError('invalid-argument', 'A valid sessionId is required.');
  }
  if (answers.length > MAX_ANSWERS_PER_ROUND) {
    throw new HttpsError('invalid-argument', `answers must not exceed ${MAX_ANSWERS_PER_ROUND}.`);
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
    const session = sessionSnap.data() as TimeAttackSessionStored;
    const profile = userSnap.data() as UserProfile;
    if (session.uid !== uid) {
      throw new HttpsError('permission-denied', 'This ranked session belongs to another user.');
    }
    if (session.sessionType !== 'time-attack-v2' || session.balanceVersion !== TIME_ATTACK_BALANCE_VERSION
        || !isGameMode(session.mode)) {
      throw new HttpsError('failed-precondition', 'This session is not a supported time-attack session.');
    }
    if (session.status === 'consumed' && session.submissionResult) {
      return session.submissionResult;
    }
    if (session.status !== 'issued') {
      throw new HttpsError('failed-precondition', 'This ranked session has already been submitted.');
    }
    const nowMs = Date.now();
    if (session.expiresAt.toMillis() < nowMs) {
      throw new HttpsError('deadline-exceeded', 'This ranked session has expired.');
    }
    if (!profile.schoolId || !profile.regionCode) {
      throw new HttpsError('failed-precondition', 'schoolId and regionCode are required for ranked play.');
    }

    const replay = replayRound({
      seed: session.seed,
      mode: session.mode,
      answers: answers.map((answer) => ({
        text: String(answer?.text ?? ''),
        elapsedMs: Number(answer?.elapsedMs ?? 0),
      })),
      timeoutGraceMs: TIMEOUT_GRACE_MS,
      maxAnswers: MAX_ANSWERS_PER_ROUND,
      maxRoundDurationMs: MAX_TIME_ATTACK_ROUND_MS,
    });
    const score = replay.score;
    const wallClockMs = nowMs - session.issuedAt.toMillis();
    const flagReasons: string[] = [];
    if (wallClockMs + CLOCK_SKEW_SLACK_MS < replay.roundDurationMs) {
      flagReasons.push('finished_faster_than_clock');
    }
    if (wallClockMs > replay.roundDurationMs + SUBMIT_LATENCY_SLACK_MS) {
      flagReasons.push('round_longer_than_reported');
    }
    if (replay.droppedAfterTimeout > 0) {
      flagReasons.push('answers_after_timeout');
    }
    const flagged = flagReasons.some((reason) => reason !== 'answers_after_timeout');

    const aggregateStates = flagged ? [] : await Promise.all(
      [session.levelBucket, TIME_ATTACK_ALL_BUCKET].map((levelBucket) => prepareAggregateState({
        tx,
        uid,
        seasonId: session.seasonId,
        levelBucket,
        schoolId: String(profile.schoolId),
        regionCode: String(profile.regionCode),
      })),
    );

    const previousSeasonBest = Number(profile.timeAttackSeasonBest ?? 0);
    const seasonBest = flagged ? previousSeasonBest : Math.max(previousSeasonBest, score.brainScore);
    const submissionResult: TimeAttackSubmissionResult = {
      attemptId: attemptRef.id,
      brainScore: score.brainScore,
      accuracyRate: score.accuracyRate,
      comboMax: score.comboMax,
      correctCount: score.correctCount,
      attemptCount: score.attemptCount,
      seasonBest,
      isNewBest: !flagged && score.brainScore > previousSeasonBest,
      flagged,
    };
    tx.set(attemptRef, {
      uid,
      sessionId,
      seasonId: session.seasonId,
      sessionType: session.sessionType,
      mode: session.mode,
      levelBucket: session.levelBucket,
      balanceVersion: session.balanceVersion,
      ...score,
      problemStats: replay.problems,
      roundDurationMs: replay.roundDurationMs,
      wallClockMs,
      droppedAfterTimeout: replay.droppedAfterTimeout,
      flagged,
      flagReasons,
      recognizedSummary: {
        strokeCount: answers.reduce((sum, answer) => sum + Number(answer?.strokeCount ?? 0), 0),
        pointCount: answers.reduce((sum, answer) => sum + Number(answer?.pointCount ?? 0), 0),
        inkHashes: answers.map((answer) => answer?.inkHash).filter(Boolean),
      },
      schoolIdSnapshot: profile.schoolId,
      regionCodeSnapshot: profile.regionCode,
      submittedAt: FieldValue.serverTimestamp(),
    });
    for (const prepared of aggregateStates) {
      applyAggregateWrites({
        tx,
        prepared,
        uid,
        seasonId: session.seasonId,
        schoolId: String(profile.schoolId),
        regionCode: String(profile.regionCode),
        score: score.brainScore,
        attemptId: attemptRef.id,
      });
    }
    tx.set(sessionRef, {
      status: 'consumed',
      attemptId: attemptRef.id,
      submissionResult,
      consumedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    tx.set(userRef, {
      timeAttackSeasonBest: seasonBest,
      timeAttackBestOverall: Math.max(Number(profile.timeAttackBestOverall ?? 0), seasonBest),
      lastSeenAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return submissionResult;
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
  const snapshots = ['global', 'school', 'region'].flatMap((scope) =>
    ['all', TIME_ATTACK_ALL_BUCKET].map((levelBucket) => ({ scope, levelBucket })),
  );
  for (const { scope, levelBucket } of snapshots) {
    const snapshotId = `${ACTIVE_SEASON_ID}_${scope}_${levelBucket}_latest`;
    const snapshotRef = db.collection('leaderboard_snapshots').doc(snapshotId);
    const query = db
      .collection('aggregates')
      .where('seasonId', '==', ACTIVE_SEASON_ID)
      .where('scope', '==', scope)
      .where('levelBucket', '==', levelBucket)
      .orderBy('avgBestBrainScore', 'desc')
      .limit(LEADERBOARD_LIMIT);

    const [aggregateSnap, previousEntriesSnap] = await Promise.all([
      query.get(),
      snapshotRef.collection('entries').get(),
    ]);
    const batch = db.batch();
    const nextEntityIds = new Set(aggregateSnap.docs.map((doc) => String(doc.data().entityId)));
    previousEntriesSnap.docs
      .filter((doc) => !nextEntityIds.has(doc.id))
      .forEach((doc) => batch.delete(doc.ref));
    batch.set(snapshotRef, {
      generatedAt: FieldValue.serverTimestamp(),
      snapshotId,
      seasonId: ACTIVE_SEASON_ID,
      scope,
      levelBucket,
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




