import { writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

import {
  GAME_MODES,
  calculateBrainScore,
  generateProblem,
  normalizeAnswer,
  type AttemptScoreInput,
} from '../src/gameEngine';

export const GOLDEN_PATH = resolve(__dirname, '..', '..', '..', 'shared', 'engine_golden.json');

const SEEDS = [1, 42, 7919, 123456789, 2147483646];
const PROBLEMS_PER_SEED = 30;

const NORMALIZE_INPUTS = ['12', ' 3 4 ', 'O7', 'l5', '-8', '8-', '1,024', 'abc', '', '-', 'S0', '9q'];

const SCORE_ATTEMPTS: AttemptScoreInput[][] = [
  [],
  [{ correct: false, elapsedMs: 4000 }],
  Array.from({ length: 20 }, (_, i) => ({ correct: i % 7 !== 3, elapsedMs: 1800 + (i * 37) })),
  Array.from({ length: 12 }, () => ({ correct: true, elapsedMs: 2500 })),
  Array.from({ length: 6 }, (_, i) => ({ correct: i % 2 === 0, elapsedMs: 9000 })),
];

export function buildGolden() {
  return {
    description: 'Shared engine vectors. Regenerate with `npm run golden` in functions/ and keep the Dart engine in sync.',
    problems: GAME_MODES.flatMap((mode) =>
      SEEDS.map((seed) => ({
        mode,
        seed,
        items: Array.from({ length: PROBLEMS_PER_SEED }, (_, index) => {
          const problem = generateProblem(seed, mode, index);
          return `${problem.prompt} = ${problem.answer}`;
        }),
      })),
    ),
    normalize: NORMALIZE_INPUTS.map((input) => ({ input, output: normalizeAnswer(input) })),
    scores: GAME_MODES.flatMap((mode) =>
      SCORE_ATTEMPTS.map((attempts) => {
        const score = calculateBrainScore(mode, attempts);
        return {
          mode,
          attempts: attempts.map((attempt) => [attempt.correct, attempt.elapsedMs]),
          brainScore: score.brainScore,
          comboMax: score.comboMax,
          correctCount: score.correctCount,
        };
      }),
    ),
  };
}

if (require.main === module) {
  writeFileSync(GOLDEN_PATH, `${JSON.stringify(buildGolden(), null, 2)}\n`);
  console.log(`wrote ${GOLDEN_PATH}`);
}
