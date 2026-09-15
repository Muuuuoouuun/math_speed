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

function maxOperand(prompt: string): number {
  return Math.max(...prompt.match(/\d+/g)!.map(Number));
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

  test('difficulty ramps up within a session: later problems use visibly larger numbers than earlier ones', () => {
    // A generic, level-agnostic proxy (largest number appearing anywhere in the prompt), averaged
    // over a quarter of a long session at a time, to avoid being sensitive to any single draw.
    for (const level of ALL_LEVELS) {
      for (const seed of SAMPLE_SEEDS) {
        const count = 300;
        const problems = generateSessionProblems(seed, level, count);
        const firstQuarter = problems.slice(0, count * 0.25).map((p) => maxOperand(p.prompt));
        const lastQuarter = problems.slice(count * 0.75).map((p) => maxOperand(p.prompt));
        const average = (values: number[]) => values.reduce((sum, v) => sum + v, 0) / values.length;
        assert.ok(
          average(lastQuarter) > average(firstQuarter),
          `level ${level} seed ${seed}: expected the session's back quarter to skew harder than its front quarter`,
        );
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
          { index: 0, level: 1, prompt: '5 + 5', answer: 10 },
          { index: 1, level: 1, prompt: '2 + 3', answer: 5 },
          { index: 2, level: 1, prompt: '9 + 1', answer: 10 },
          { index: 3, level: 1, prompt: '4 + 1', answer: 5 },
          { index: 4, level: 1, prompt: '6 + 5', answer: 11 },
        ],
      },
      {
        seed: 2024,
        level: 7,
        count: 5,
        expected: [
          { index: 0, level: 7, prompt: '7 + 8 - 8', answer: 7 },
          { index: 1, level: 7, prompt: '(3 × 2) + 11', answer: 17 },
          { index: 2, level: 7, prompt: '17 + 9 - 3', answer: 23 },
          { index: 3, level: 7, prompt: '(5 × 6) + 9', answer: 39 },
          { index: 4, level: 7, prompt: '28 + 5 - 5', answer: 28 },
        ],
      },
      {
        seed: 2024,
        level: 9,
        count: 5,
        expected: [
          { index: 0, level: 9, prompt: '(8 × 6) ÷ 3', answer: 16 },
          { index: 1, level: 9, prompt: '(4 × 6) ÷ 3', answer: 8 },
          { index: 2, level: 9, prompt: '(6 × 15) ÷ 5', answer: 18 },
          { index: 3, level: 9, prompt: '(7 × 8) ÷ 2', answer: 28 },
          { index: 4, level: 9, prompt: '(5 × 12) ÷ 3', answer: 20 },
        ],
      },
      {
        seed: 2024,
        level: 10,
        count: 5,
        expected: [
          { index: 0, level: 10, prompt: '(10 × 4) - (3 × 8)', answer: 16 },
          { index: 1, level: 10, prompt: '(12 × 5) - (4 × 9)', answer: 24 },
          { index: 2, level: 10, prompt: '(12 × 4) - (2 × 13)', answer: 22 },
          { index: 3, level: 10, prompt: '(5 × 24) - (17 × 6)', answer: 18 },
          { index: 4, level: 10, prompt: '(7 × 20) - (12 × 9)', answer: 32 },
        ],
      },
    ];

    for (const { seed, level, count, expected } of cases) {
      assert.deepEqual(generateSessionProblems(seed, level, count), expected, `seed=${seed} level=${level}`);
    }
  });
});
