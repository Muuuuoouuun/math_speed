import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

import { generateSessionProblems, type MathProblem } from './mathEngine.ts';

const ALL_LEVELS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
const SAMPLE_SEEDS = [1, 42, 2024, 123456, 777777, 999999999, 0x7ffffffe];

function evaluatePrompt(prompt: string): number {
  const expr = prompt.replace(/×/g, '*').replace(/÷/g, '/');
  assert.match(expr, /^[\d\s+\-*/()]+$/, `unexpected characters in prompt: ${prompt}`);
  return Function(`"use strict"; return (${expr});`)() as number;
}

describe('generateSessionProblems', () => {
  test('is deterministic for a given seed/level/count', () => {
    for (const seed of SAMPLE_SEEDS) {
      for (const level of ALL_LEVELS) {
        const first = generateSessionProblems(seed, level, 12);
        const second = generateSessionProblems(seed, level, 12);
        assert.deepEqual(second, first, `seed=${seed} level=${level}`);
      }
    }
  });

  test('different levels diverge for the same seed', () => {
    const byLevel = ALL_LEVELS.map((level) => generateSessionProblems(2024, level, 6));
    const serialized = byLevel.map((problems) => JSON.stringify(problems));
    assert.equal(new Set(serialized).size, serialized.length, 'expected every level to produce a distinct sequence');
  });

  test('returns problems with sequential indices and the requested level', () => {
    const problems = generateSessionProblems(555, 4, 9);
    assert.equal(problems.length, 9);
    problems.forEach((problem, i) => {
      assert.equal(problem.index, i);
      assert.equal(problem.level, 4);
    });
  });

  test('every generated answer is a non-negative integer, for every level', () => {
    for (const level of ALL_LEVELS) {
      for (const seed of SAMPLE_SEEDS) {
        const problems = generateSessionProblems(seed, level, 30);
        for (const problem of problems) {
          assert.ok(
            Number.isInteger(problem.answer),
            `level ${level} seed ${seed} produced a non-integer answer: ${JSON.stringify(problem)}`,
          );
          assert.ok(
            problem.answer >= 0,
            `level ${level} seed ${seed} produced a negative answer: ${JSON.stringify(problem)}`,
          );
        }
      }
    }
  });

  test('the displayed prompt always evaluates to the stored answer', () => {
    for (const level of ALL_LEVELS) {
      for (const seed of SAMPLE_SEEDS) {
        const problems = generateSessionProblems(seed, level, 20);
        for (const problem of problems) {
          assert.equal(
            evaluatePrompt(problem.prompt),
            problem.answer,
            `level ${level} seed ${seed}: "${problem.prompt}" did not evaluate to ${problem.answer}`,
          );
        }
      }
    }
  });

  test('level 6 (exact division) and level 9 (multi multiply-divide) never leave a remainder', () => {
    for (const level of [6, 9]) {
      for (const seed of SAMPLE_SEEDS) {
        const problems = generateSessionProblems(seed, level, 25);
        for (const problem of problems) {
          assert.ok(Number.isInteger(problem.answer), `level ${level} produced a fractional answer: ${problem.prompt}`);
        }
      }
    }
  });

  test('level 10 (boss round) always subtracts the smaller product from the larger one', () => {
    for (const seed of SAMPLE_SEEDS) {
      const problems = generateSessionProblems(seed, 10, 25);
      for (const problem of problems) {
        const match = problem.prompt.match(/^\((\d+) × (\d+)\) - \((\d+) × (\d+)\)$/);
        assert.ok(match, `unexpected boss round prompt shape: ${problem.prompt}`);
        const [, a, b, c, d] = match!.map(Number) as unknown as [never, number, number, number, number];
        assert.ok(a * b >= c * d, `expected the first product to be >= the second in "${problem.prompt}"`);
      }
    }
  });

  test('golden vectors stay pinned across refactors', () => {
    const cases: Array<{ seed: number; level: number; count: number; expected: MathProblem[] }> = [
      {
        seed: 2024,
        level: 1,
        count: 5,
        expected: [
          { index: 0, level: 1, prompt: '5 + 7', answer: 12 },
          { index: 1, level: 1, prompt: '2 + 9', answer: 11 },
          { index: 2, level: 1, prompt: '9 + 7', answer: 16 },
          { index: 3, level: 1, prompt: '4 + 8', answer: 12 },
          { index: 4, level: 1, prompt: '6 + 5', answer: 11 },
        ],
      },
      {
        seed: 2024,
        level: 7,
        count: 5,
        expected: [
          { index: 0, level: 7, prompt: '29 + 8 - 8', answer: 29 },
          { index: 1, level: 7, prompt: '(3 × 2) + 14', answer: 20 },
          { index: 2, level: 7, prompt: '15 + 9 - 3', answer: 21 },
          { index: 3, level: 7, prompt: '(5 × 6) + 23', answer: 53 },
          { index: 4, level: 7, prompt: '20 + 5 - 5', answer: 20 },
        ],
      },
      {
        seed: 2024,
        level: 9,
        count: 5,
        expected: [
          { index: 0, level: 9, prompt: '(3 × 2) ÷ 3', answer: 2 },
          { index: 1, level: 9, prompt: '(3 × 4) ÷ 3', answer: 4 },
          { index: 2, level: 9, prompt: '(5 × 1) ÷ 5', answer: 1 },
          { index: 3, level: 9, prompt: '(6 × 4) ÷ 2', answer: 12 },
          { index: 4, level: 9, prompt: '(12 × 4) ÷ 3', answer: 16 },
        ],
      },
      {
        seed: 2024,
        level: 10,
        count: 5,
        expected: [
          { index: 0, level: 10, prompt: '(8 × 34) - (18 × 6)', answer: 164 },
          { index: 1, level: 10, prompt: '(28 × 5) - (9 × 11)', answer: 41 },
          { index: 2, level: 10, prompt: '(26 × 5) - (8 × 15)', answer: 10 },
          { index: 3, level: 10, prompt: '(9 × 41) - (26 × 9)', answer: 135 },
          { index: 4, level: 10, prompt: '(8 × 48) - (20 × 9)', answer: 204 },
        ],
      },
    ];

    for (const { seed, level, count, expected } of cases) {
      assert.deepEqual(generateSessionProblems(seed, level, count), expected, `seed=${seed} level=${level}`);
    }
  });
});
