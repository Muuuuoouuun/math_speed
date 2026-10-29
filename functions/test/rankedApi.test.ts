import assert from 'node:assert/strict';
import { generateKeyPairSync } from 'node:crypto';
import { afterEach, beforeEach, describe, it, mock } from 'node:test';
import { getFirestore } from 'firebase-admin/firestore';
import { cert, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

initializeApp({
  projectId: 'demo-brain-math-unit-tests',
  credential: cert({
    projectId: 'demo-brain-math-unit-tests',
    clientEmail: 'unit-test@example.invalid',
    privateKey: generateKeyPairSync('rsa', { modulusLength: 2048 }).privateKey
      .export({ type: 'pkcs8', format: 'pem' }).toString(),
  }),
});
const {
  createRankedSession,
  createTimeAttackSessionV2,
  submitRankedSession,
  submitTimeAttackSessionV2,
  syncUserClaims,
  upsertPlayerProfile,
} = require('../src/index') as typeof import('../src/index');
import { generateProblem, replayRound } from '../src/gameEngine';
import { generateSessionProblems } from '../src/mathEngine';

// Exercise the actual callable handlers against an in-memory Firestore boundary.
// The test-only certificate is generated in memory; no real credentials or network are used.
const documents = new Map<string, Record<string, any>>();
const authClaims = new Map<string, Record<string, any>>();
let nowMs = 1800000000000;
let nextId = 0;

function document(path: string): any {
  return {
    id: path.split('/').at(-1),
    path,
    get: async () => snapshot(path),
    set: async (data: Record<string, any>, options?: { merge?: boolean }) => set(path, data, options),
  };
}

function snapshot(path: string): any {
  return { exists: documents.has(path), data: () => documents.get(path) };
}

function set(path: string, data: Record<string, any>, options?: { merge?: boolean }) {
  documents.set(path, options?.merge ? { ...documents.get(path), ...data } : { ...data });
}

function request(data: unknown, uid = 'player'): any {
  return { data, auth: { uid, token: {} } };
}

beforeEach(() => {
  nowMs = 1800000000000;
  nextId = 0;
  documents.clear();
  authClaims.clear();
  documents.set('users/player', { schoolId: 'school-a', regionCode: 'region-a', role: 'player' });
  mock.method(Date, 'now', () => nowMs);
  const auth = getAuth();
  mock.method(auth, 'getUser', (async (uid: string) => ({ uid, customClaims: authClaims.get(uid) })) as any);
  mock.method(auth, 'setCustomUserClaims', async (uid: string, claims: Record<string, any> | null) => {
    authClaims.set(uid, { ...claims });
  });
  const db = getFirestore();
  mock.method(db, 'collection', ((name: string) => ({
    doc: (id?: string) => document(`${name}/${id ?? `unit-${++nextId}`}`),
  })) as any);
  mock.method(db, 'runTransaction', (async (callback: (tx: any) => Promise<any>) => {
    let wrote = false;
    return callback({
      get: async (ref: any) => {
        assert.equal(wrote, false, 'Firestore reads must precede transaction writes');
        return snapshot(ref.path);
      },
      set: (ref: any, data: Record<string, any>, options?: { merge?: boolean }) => {
        wrote = true;
        set(ref.path, data, options);
      },
    });
  }) as any);
});

afterEach(() => mock.restoreAll());

describe('ranked callable contracts', () => {
  it('rejects a client-selected question count before issuing a session', async () => {
    await assert.rejects(createRankedSession.run(request({ level: 1, problemCount: 30 })),
      { code: 'invalid-argument' });
    assert.equal([...documents.keys()].some((path) => path.startsWith('ranked_sessions/')), false);
  });
  it('keeps the ten-level API and its fixed-round scoring available', async () => {
    const session = await createRankedSession.run(request({ level: 6 }));
    assert.equal(session.level, 6);
    assert.equal(session.problemCount, 14);
    const answers = generateSessionProblems(session.seed, session.level, session.problemCount)
      .map((problem) => ({ text: String(problem.answer), elapsedMs: 2000 }));
    const result = await submitRankedSession.run(request({ sessionId: session.sessionId, answers }));
    assert.equal(result.correctCount, 14);
    assert.ok(documents.has('user_season_bests/2026_s1_player_all'));
    assert.equal(documents.has('user_season_bests/2026_s1_player_time-attack-all'), false);
  });

  it('issues the V2 contract and stores only time-attack aggregates', async () => {
    const session = await createTimeAttackSessionV2.run(request({ mode: 'simpleCalculation' }));
    assert.equal(session.levelBucket, 'mode-simpleCalculation');
    assert.equal(session.balanceVersion, 'game_balance_v2');
    assert.equal(session.maxAnswers, 400);
    assert.equal(session.maxRoundDurationMs, 540000);
    const answers = Array.from({ length: 30 }, (_, index) => ({
      text: String(generateProblem(session.seed, session.mode, index).answer), elapsedMs: 2000,
    }));
    const replay = replayRound({ seed: session.seed, mode: session.mode, answers, timeoutGraceMs: 1500 });
    nowMs += replay.roundDurationMs;
    const result = await submitTimeAttackSessionV2.run(request({ sessionId: session.sessionId, answers }));
    assert.equal(result.correctCount, 30);
    assert.equal(result.flagged, false);
    assert.equal(result.isNewBest, true);
    assert.ok(documents.has('user_season_bests/2026_s1_player_time-attack-all'));
    assert.equal(documents.has('user_season_bests/2026_s1_player_all'), false);
    assert.equal(documents.get('users/player')?.currentSeasonBest, undefined);

    const count = documents.size;
    const retry = await submitTimeAttackSessionV2.run(request({ sessionId: session.sessionId, answers }));
    assert.deepEqual(retry, result);
    assert.equal(documents.size, count, 'A retry must not add an attempt or aggregate again');
  });

  it('rejects using a session with the other scoring API', async () => {
    const fixed = await createRankedSession.run(request({ level: 1 }));
    const timed = await createTimeAttackSessionV2.run(request({ mode: 'simpleCalculation' }));
    await assert.rejects(submitTimeAttackSessionV2.run(request({ sessionId: fixed.sessionId, answers: [] })),
      { code: 'failed-precondition' });
    await assert.rejects(submitRankedSession.run(request({ sessionId: timed.sessionId, answers: [] })),
      { code: 'failed-precondition' });
  });

  it('records an implausibly fast V2 submission without promoting it into rankings', async () => {
    const session = await createTimeAttackSessionV2.run(request({ mode: 'simpleCalculation' }));
    const answers = [{ text: String(generateProblem(session.seed, session.mode, 0).answer), elapsedMs: 250 }];
    const result = await submitTimeAttackSessionV2.run(request({ sessionId: session.sessionId, answers }));
    assert.equal(result.flagged, true);
    assert.equal(result.seasonBest, 0);
    assert.equal(result.isNewBest, false);
    assert.equal([...documents.keys()].some((path) => path.startsWith('aggregates/')), false);
  });
});

describe('profile callable authorization', () => {
  it('repairs a forged stored role during claims sync without granting it', async () => {
    documents.get('users/player')!.role = 'admin';
    await syncUserClaims.run(request({ role: 'admin' }));
    assert.equal(authClaims.get('player')?.role, 'player');
    assert.equal(documents.get('users/player')?.role, 'player');
  });

  it('ignores forged roles from both the existing profile and profile-save input', async () => {
    documents.get('users/player')!.role = 'admin';
    await upsertPlayerProfile.run(request({
      displayName: 'Player', schoolId: 'school-b', regionCode: 'region-b', grade: 3, role: 'ops',
    }));
    assert.equal(authClaims.get('player')?.role, 'player');
    assert.equal(documents.get('users/player')?.role, 'player');
    assert.equal(authClaims.get('player')?.schoolId, 'school-b');
  });

  it('keeps an existing server-assigned role and unrelated claims after a profile save', async () => {
    authClaims.set('player', { role: 'ops', support: true });
    await upsertPlayerProfile.run(request({
      displayName: 'Operator', schoolId: 'school-b', regionCode: 'region-b', grade: 6,
    }));
    assert.deepEqual(authClaims.get('player'), {
      role: 'ops', support: true, schoolId: 'school-b', regionCode: 'region-b',
    });
    assert.equal(documents.get('users/player')?.role, 'ops');
  });
});
