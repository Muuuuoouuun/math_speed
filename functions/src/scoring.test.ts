import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

import { calculateBrainScore, type AttemptScoreInput } from './scoring.ts';

function attempts(pattern: Array<{ correct: boolean; elapsedMs: number }>): AttemptScoreInput[] {
  return pattern;
}

describe('calculateBrainScore', () => {
  test('returns an all-zero breakdown for an empty attempt list', () => {
    assert.deepEqual(calculateBrainScore(1, []), {
      brainScore: 0,
      accuracyRate: 0,
      speedRate: 0,
      basePoints: 0,
      comboBonus: 0,
      comboMax: 0,
      correctCount: 0,
    });
  });

  test('every wrong answer scores zero regardless of speed', () => {
    const result = calculateBrainScore(
      5,
      attempts([
        { correct: false, elapsedMs: 100 },
        { correct: false, elapsedMs: 5000 },
        { correct: false, elapsedMs: 900 },
      ]),
    );
    assert.equal(result.correctCount, 0);
    assert.equal(result.accuracyRate, 0);
    assert.equal(result.comboMax, 0);
    assert.equal(result.comboBonus, 0);
    assert.equal(result.basePoints, 0);
    assert.equal(result.brainScore, 0);
  });

  test('solving exactly at the level target yields speedRate 1 and full accuracy weighting', () => {
    const result = calculateBrainScore(
      1,
      attempts(Array.from({ length: 5 }, () => ({ correct: true, elapsedMs: 1500 }))),
    );
    assert.equal(result.correctCount, 5);
    assert.equal(result.accuracyRate, 1);
    assert.equal(result.speedRate, 1);
    assert.equal(result.comboMax, 5);
    const expectedBasePoints = 5 * (110 + 1 * 32) * 1;
    assert.equal(result.basePoints, expectedBasePoints);
    const expectedComboBonus = 5 * (8 + 1 * 2);
    assert.equal(result.comboBonus, expectedComboBonus);
    assert.equal(result.brainScore, Math.round(expectedBasePoints * 1 + expectedComboBonus));
  });

  test('speedRate is clamped to 0.25 when far slower than the max solve time', () => {
    const result = calculateBrainScore(1, attempts([{ correct: true, elapsedMs: 999_999 }]));
    assert.equal(result.speedRate, 0.25);
  });

  test('speedRate is clamped to 1.2 when far faster than the target solve time', () => {
    const result = calculateBrainScore(1, attempts([{ correct: true, elapsedMs: 0 }]));
    assert.equal(result.speedRate, 1.2);
  });

  test('combo streak resets on a wrong answer and comboMax tracks the longest streak', () => {
    const result = calculateBrainScore(
      3,
      attempts([
        { correct: true, elapsedMs: 1700 },
        { correct: true, elapsedMs: 1700 },
        { correct: false, elapsedMs: 1700 },
        { correct: true, elapsedMs: 1700 },
        { correct: true, elapsedMs: 1700 },
        { correct: true, elapsedMs: 1700 },
      ]),
    );
    assert.equal(result.correctCount, 5);
    assert.equal(result.comboMax, 3);
  });

  test('higher levels weigh correct answers more heavily, independent of speed', () => {
    const pattern = attempts([
      { correct: true, elapsedMs: 1700 },
      { correct: true, elapsedMs: 1700 },
      { correct: false, elapsedMs: 1700 },
    ]);
    const low = calculateBrainScore(1, pattern);
    const high = calculateBrainScore(10, pattern);
    assert.equal(low.basePoints, 2 * (110 + 1 * 32) * (0.7 + low.accuracyRate * 0.3));
    assert.equal(high.basePoints, 2 * (110 + 10 * 32) * (0.7 + high.accuracyRate * 0.3));
    assert.ok(high.basePoints > low.basePoints, 'higher levels should award more base points for the same accuracy');
  });

  test('the same attempts score differently across levels because each level targets a different pace', () => {
    const pattern = attempts(Array.from({ length: 4 }, () => ({ correct: true, elapsedMs: 1600 })));
    const level1 = calculateBrainScore(1, pattern);
    const level10 = calculateBrainScore(10, pattern);
    // A boss round is allowed far longer than a single-digit sum, so the same 1600ms average is
    // an ordinary pace at level 1 but an exceptional one at level 10.
    assert.ok(level10.speedRate > level1.speedRate);
  });

  test('every level keeps speed a live signal rather than pinning to a clamp', () => {
    // Each level's target is fitted to its own problem shape, so a player solving at roughly the
    // intended pace must land strictly inside the 0.25-1.2 clamp at every level - otherwise speed
    // stops differentiating exactly where the problems are hardest.
    const targets = [1500, 1600, 2000, 2500, 1800, 1850, 2700, 2900, 3000, 4000];
    targets.forEach((target, i) => {
      const level = i + 1;
      const atTarget = calculateBrainScore(level, attempts([{ correct: true, elapsedMs: target }]));
      assert.equal(atTarget.speedRate, 1, `level ${level} should read exactly 1.0 at its own target pace`);

      const slower = calculateBrainScore(level, attempts([{ correct: true, elapsedMs: Math.round(target * 1.4) }]));
      assert.ok(slower.speedRate > 0.25, `level ${level} pinned to the slow clamp at 1.4x its target`);
      assert.ok(slower.speedRate < 1, `level ${level} should read slower than target at 1.4x`);

      const faster = calculateBrainScore(level, attempts([{ correct: true, elapsedMs: Math.round(target * 0.7) }]));
      assert.ok(faster.speedRate > 1, `level ${level} should reward beating its target`);
    });
  });

  test('harder levels pay more per correct answer at a comparable pace', () => {
    // Fitting each level's pace to its content is what keeps this true: when every level reads a
    // similar speedRate, difficultyWeight decides the reward, so grinding an easy level never beats
    // playing a hard one.
    const targets = [1500, 1600, 2000, 2500, 1800, 1850, 2700, 2900, 3000, 4000];
    const perProblem = targets.map((target, i) =>
      calculateBrainScore(i + 1, attempts([{ correct: true, elapsedMs: target }])).brainScore,
    );
    for (let i = 1; i < perProblem.length; i++) {
      assert.ok(
        perProblem[i] > perProblem[i - 1],
        `level ${i + 1} should out-pay level ${i} per problem (${perProblem[i]} vs ${perProblem[i - 1]})`,
      );
    }
  });

  test('partial accuracy scales basePoints between the 0.7x and 1.0x multipliers', () => {
    const halfCorrect = calculateBrainScore(
      4,
      attempts([
        { correct: true, elapsedMs: 1650 },
        { correct: false, elapsedMs: 1650 },
      ]),
    );
    assert.equal(halfCorrect.accuracyRate, 0.5);
    const expectedBasePoints = 1 * (110 + 4 * 32) * (0.7 + 0.5 * 0.3);
    assert.equal(halfCorrect.basePoints, expectedBasePoints);
  });
});
