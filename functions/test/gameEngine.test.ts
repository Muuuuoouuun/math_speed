import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { describe, it } from 'node:test';

import {
  GAME_MODES,
  generateProblem,
  modeConfig,
  normalizeAnswer,
  replayRound,
  type GameMode,
} from '../src/gameEngine';
import { GOLDEN_PATH, buildGolden } from '../scripts/golden';

function evaluate(prompt: string): number {
  const [left, operator, right] = prompt.split(' ');
  const a = Number(left);
  const b = Number(right);
  switch (operator) {
    case '+':
      return a + b;
    case '-':
      return a - b;
    case 'x':
      return a * b;
    case '/':
      return a / b;
    default:
      throw new Error(`unknown operator in ${prompt}`);
  }
}

function solveRound(seed: number, mode: GameMode, count: number, elapsedMs: number) {
  return Array.from({ length: count }, (_, index) => ({
    text: String(generateProblem(seed, mode, index).answer),
    elapsedMs,
  }));
}

describe('generateProblem', () => {
  it('is deterministic and every answer matches its prompt', () => {
    for (const mode of GAME_MODES) {
      for (let index = 0; index < 500; index++) {
        const problem = generateProblem(987654, mode, index);
        assert.deepEqual(problem, generateProblem(987654, mode, index));
        assert.equal(evaluate(problem.prompt), problem.answer, problem.prompt);
        assert.ok(problem.answer >= 0, problem.prompt);
        assert.ok(Number.isInteger(problem.answer), problem.prompt);
      }
    }
  });
});

describe('golden vectors', () => {
  it('match shared/engine_golden.json (run `npm run golden` after an intentional change)', () => {
    const stored = JSON.parse(readFileSync(GOLDEN_PATH, 'utf8'));
    assert.deepEqual(buildGolden(), stored);
  });
});

describe('normalizeAnswer', () => {
  it('keeps digits, maps look-alike letters and drops noise', () => {
    assert.equal(normalizeAnswer(' 1 2 '), '12');
    assert.equal(normalizeAnswer('O7'), '07');
    assert.equal(normalizeAnswer('l5'), '15');
    assert.equal(normalizeAnswer('8-'), '8');
    assert.equal(normalizeAnswer('-'), '');
    assert.equal(normalizeAnswer(undefined), '');
  });
});

describe('replayRound', () => {
  it('accepts a perfect round that fits in the time budget', () => {
    const replay = replayRound({
      seed: 5,
      mode: 'simpleCalculation',
      answers: solveRound(5, 'simpleCalculation', 30, 2000),
      timeoutGraceMs: 1500,
    });
    assert.equal(replay.droppedAfterTimeout, 0);
    assert.equal(replay.score.correctCount, 30);
    assert.equal(replay.score.comboMax, 30);
  });

  it('drops answers that would have arrived after the clock ran out', () => {
    const config = modeConfig('tripleDigit');
    // 오답만 제출하면 보너스가 없으므로 초기 시간 안에 들어가는 답안 수만 인정됩니다.
    const answers = Array.from({ length: 40 }, () => ({ text: '0', elapsedMs: 5000 }));
    const replay = replayRound({ seed: 9, mode: 'tripleDigit', answers, timeoutGraceMs: 0 });
    assert.equal(replay.problems.length, Math.floor(config.initialTimeMs / 5000));
    assert.equal(replay.droppedAfterTimeout, 40 - replay.problems.length);
    assert.equal(replay.roundDurationMs, config.initialTimeMs);
  });

  it('clamps impossible elapsed values instead of trusting them', () => {
    const answers = solveRound(11, 'fourOperations', 5, 0);
    const replay = replayRound({ seed: 11, mode: 'fourOperations', answers, timeoutGraceMs: 0 });
    assert.ok(replay.problems.every((problem) => problem.ms === 250));
  });

  it('ends at the answer limit without inventing remaining play time', () => {
    const replay = replayRound({
      seed: 5,
      mode: 'simpleCalculation',
      answers: solveRound(5, 'simpleCalculation', 400, 250),
      timeoutGraceMs: 1500,
      maxAnswers: 400,
      maxRoundDurationMs: 540000,
    });
    assert.equal(replay.problems.length, 400);
    assert.equal(replay.roundDurationMs, 100000);
    assert.equal(replay.droppedAfterTimeout, 0);
  });

  it('enforces the overall duration limit even when answers replenish the timer', () => {
    const replay = replayRound({
      seed: 5,
      mode: 'simpleCalculation',
      answers: solveRound(5, 'simpleCalculation', 400, 1500),
      timeoutGraceMs: 1500,
      maxAnswers: 400,
      maxRoundDurationMs: 540000,
    });
    assert.equal(replay.problems.length, 360);
    assert.equal(replay.roundDurationMs, 540000);
    assert.equal(replay.droppedAfterTimeout, 40);
  });
});
