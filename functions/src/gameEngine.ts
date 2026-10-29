// 클라이언트(app/lib/features/game/domain)와 1:1로 대응하는 서버 권위 게임 엔진입니다.
// 문제 생성, 정답 정규화, 점수 계산 로직을 바꾸면 반드시 양쪽을 함께 수정하고
// shared/engine_golden.json 을 갱신해야 합니다 (`npm run golden`).

export const GAME_MODES = ['simpleCalculation', 'fourOperations', 'doubleDigit', 'tripleDigit'] as const;
export type GameMode = (typeof GAME_MODES)[number];

export type GameModeConfig = {
  mode: GameMode;
  initialTimeMs: number;
  bonusTimeMs: number;
  maxTimeMs: number;
  targetCorrectPerMinute: number;
  difficultyWeight: number;
};

const MODE_CONFIGS: Record<GameMode, GameModeConfig> = {
  simpleCalculation: {
    mode: 'simpleCalculation',
    initialTimeMs: 45000,
    bonusTimeMs: 1700,
    maxTimeMs: 62000,
    targetCorrectPerMinute: 26,
    difficultyWeight: 90,
  },
  fourOperations: {
    mode: 'fourOperations',
    initialTimeMs: 55000,
    bonusTimeMs: 1500,
    maxTimeMs: 72000,
    targetCorrectPerMinute: 18,
    difficultyWeight: 120,
  },
  doubleDigit: {
    mode: 'doubleDigit',
    initialTimeMs: 60000,
    bonusTimeMs: 1400,
    maxTimeMs: 76000,
    targetCorrectPerMinute: 14,
    difficultyWeight: 150,
  },
  tripleDigit: {
    mode: 'tripleDigit',
    initialTimeMs: 70000,
    bonusTimeMs: 1300,
    maxTimeMs: 86000,
    targetCorrectPerMinute: 10,
    difficultyWeight: 190,
  },
};

export function isGameMode(value: unknown): value is GameMode {
  return typeof value === 'string' && (GAME_MODES as readonly string[]).includes(value);
}

export function modeConfig(mode: GameMode): GameModeConfig {
  return MODE_CONFIGS[mode];
}

export function modeIndex(mode: GameMode): number {
  return GAME_MODES.indexOf(mode);
}

export type MathProblem = {
  index: number;
  level: number;
  prompt: string;
  answer: number;
};

export class DeterministicRng {
  private state: number;

  constructor(seed: number) {
    const normalized = seed >>> 0;
    this.state = normalized === 0 ? 0x6d2b79f5 : normalized;
  }

  nextInt(maxExclusive: number): number {
    this.state = (this.state ^ (this.state << 13)) >>> 0;
    this.state = (this.state ^ (this.state >>> 17)) >>> 0;
    this.state = (this.state ^ (this.state << 5)) >>> 0;
    const value = this.state & 0x7fffffff;
    return maxExclusive === 0 ? 0 : value % maxExclusive;
  }

  between(minInclusive: number, maxInclusive: number): number {
    return minInclusive + this.nextInt((maxInclusive - minInclusive) + 1);
  }
}

export function generateProblem(seed: number, mode: GameMode, index: number): MathProblem {
  const mixed = (seed ^ ((modeIndex(mode) + 1) * 7919) ^ ((index + 1) * 104729)) >>> 0;
  const rng = new DeterministicRng(mixed);

  switch (mode) {
    case 'simpleCalculation':
      return simpleProblem(rng, index);
    case 'fourOperations':
      return fourOperationsProblem(rng, index);
    case 'doubleDigit':
      return doubleDigitProblem(rng, index);
    case 'tripleDigit':
      return tripleDigitProblem(rng, index);
  }
}

function simpleProblem(rng: DeterministicRng, index: number): MathProblem {
  if (rng.nextInt(2) === 0) {
    const a = rng.between(1, 9);
    const b = rng.between(1, 9);
    return { index, level: 1, prompt: `${a} + ${b}`, answer: a + b };
  }

  const a = rng.between(5, 18);
  const b = rng.between(1, a - 1);
  return { index, level: 1, prompt: `${a} - ${b}`, answer: a - b };
}

function fourOperationsProblem(rng: DeterministicRng, index: number): MathProblem {
  switch (rng.nextInt(4)) {
    case 0: {
      const a = rng.between(4, 24);
      const b = rng.between(3, 19);
      return { index, level: 2, prompt: `${a} + ${b}`, answer: a + b };
    }
    case 1: {
      const a = rng.between(12, 36);
      const b = rng.between(3, a - 2);
      return { index, level: 2, prompt: `${a} - ${b}`, answer: a - b };
    }
    case 2: {
      const a = rng.between(2, 9);
      const b = rng.between(2, 9);
      return { index, level: 2, prompt: `${a} x ${b}`, answer: a * b };
    }
    default: {
      const divisor = rng.between(2, 9);
      const quotient = rng.between(2, 9);
      return { index, level: 2, prompt: `${divisor * quotient} / ${divisor}`, answer: quotient };
    }
  }
}

function doubleDigitProblem(rng: DeterministicRng, index: number): MathProblem {
  switch (rng.nextInt(3)) {
    case 0: {
      const a = rng.between(12, 79);
      const b = rng.between(11, 69);
      return { index, level: 3, prompt: `${a} + ${b}`, answer: a + b };
    }
    case 1: {
      const a = rng.between(45, 99);
      const b = rng.between(10, a - 9);
      return { index, level: 3, prompt: `${a} - ${b}`, answer: a - b };
    }
    default: {
      const a = rng.between(10, 49);
      const b = rng.between(2, 9);
      return { index, level: 3, prompt: `${a} x ${b}`, answer: a * b };
    }
  }
}

function tripleDigitProblem(rng: DeterministicRng, index: number): MathProblem {
  switch (rng.nextInt(3)) {
    case 0: {
      const a = rng.between(120, 899);
      const b = rng.between(110, 799);
      return { index, level: 4, prompt: `${a} + ${b}`, answer: a + b };
    }
    case 1: {
      const a = rng.between(320, 999);
      const b = rng.between(100, a - 50);
      return { index, level: 4, prompt: `${a} - ${b}`, answer: a - b };
    }
    default: {
      const a = rng.between(100, 499);
      const b = rng.between(2, 9);
      return { index, level: 4, prompt: `${a} x ${b}`, answer: a * b };
    }
  }
}

const LOOKALIKE_DIGITS: Record<string, string> = {
  O: '0',
  o: '0',
  D: '0',
  l: '1',
  I: '1',
  '|': '1',
  Z: '2',
  z: '2',
  S: '5',
  s: '5',
  b: '6',
  g: '9',
  q: '9',
};

// 손글씨 인식 결과에서 숫자만 남깁니다. 숫자와 모양이 비슷한 문자는 숫자로 치환합니다.
export function normalizeAnswer(value: string | undefined | null): string {
  let result = '';
  for (const char of value ?? '') {
    const mapped = LOOKALIKE_DIGITS[char] ?? char;
    if (mapped >= '0' && mapped <= '9') {
      result += mapped;
    } else if (mapped === '-' && result.length === 0) {
      result += mapped;
    }
  }
  return result === '-' ? '' : result;
}

export type AttemptScoreInput = {
  correct: boolean;
  elapsedMs: number;
};

export type ScoreBreakdown = {
  brainScore: number;
  accuracyRate: number;
  speedRate: number;
  correctPerMinute: number;
  basePoints: number;
  comboBonus: number;
  comboMax: number;
  correctCount: number;
  attemptCount: number;
};

export function calculateBrainScore(mode: GameMode, attempts: AttemptScoreInput[]): ScoreBreakdown {
  if (attempts.length === 0) {
    return {
      brainScore: 0,
      accuracyRate: 0,
      speedRate: 0,
      correctPerMinute: 0,
      basePoints: 0,
      comboBonus: 0,
      comboMax: 0,
      correctCount: 0,
      attemptCount: 0,
    };
  }

  const config = modeConfig(mode);
  const total = attempts.length;
  const correctCount = attempts.filter((attempt) => attempt.correct).length;
  const accuracyRate = correctCount / total;
  const elapsedTotal = attempts.reduce((sum, attempt) => sum + attempt.elapsedMs, 0);
  const correctPerMinute = correctCount === 0 ? 0 : correctCount / (elapsedTotal / 60000);
  const speedRate = Math.min(1.35, Math.max(0.35, correctPerMinute / config.targetCorrectPerMinute));

  let combo = 0;
  let comboMax = 0;
  for (const attempt of attempts) {
    combo = attempt.correct ? combo + 1 : 0;
    comboMax = Math.max(comboMax, combo);
  }

  const basePoints = correctCount * config.difficultyWeight * (0.6 + (accuracyRate * 0.4));
  const comboBonus = comboMax * (10 + (modeIndex(mode) * 8));
  const brainScore = roundHalfAwayFromZero((basePoints * speedRate) + comboBonus);

  return {
    brainScore,
    accuracyRate,
    speedRate,
    correctPerMinute,
    basePoints,
    comboBonus,
    comboMax,
    correctCount,
    attemptCount: total,
  };
}

// Dart의 double.round()와 같은 반올림 규칙입니다.
function roundHalfAwayFromZero(value: number): number {
  return value < 0 ? -Math.round(-value) : Math.round(value);
}

export const MIN_PROBLEM_ELAPSED_MS = 250;
export const MAX_PROBLEM_ELAPSED_MS = 99999;

export function clampElapsed(value: unknown): number {
  const numeric = Math.round(Number(value));
  if (!Number.isFinite(numeric)) {
    return MAX_PROBLEM_ELAPSED_MS;
  }
  return Math.min(MAX_PROBLEM_ELAPSED_MS, Math.max(MIN_PROBLEM_ELAPSED_MS, numeric));
}

export type ReplayAnswer = {
  text: string;
  elapsedMs: number;
};

export type ReplayedProblem = {
  i: number;
  ok: boolean;
  ms: number;
  recognized: string;
  expected: string;
};

export type RoundReplay = {
  problems: ReplayedProblem[];
  // 제한 시간이 끝난 뒤에 제출된 것으로 판정되어 버려진 답안 수
  droppedAfterTimeout: number;
  // 마지막 답안 이후 남아 있던 시간까지 합친, 서버가 계산한 라운드 길이
  roundDurationMs: number;
  score: ScoreBreakdown;
};

// 클라이언트 타이머 규칙(초기 시간, 정답 보너스, 최대 시간)을 그대로 재생해
// 시간 안에 실제로 풀 수 있었던 답안만 채점합니다.
export function replayRound(options: {
  seed: number;
  mode: GameMode;
  answers: ReplayAnswer[];
  timeoutGraceMs: number;
  maxRoundDurationMs?: number;
  maxAnswers?: number;
}): RoundReplay {
  const { seed, mode, answers, timeoutGraceMs } = options;
  const maxRoundDurationMs = options.maxRoundDurationMs ?? Number.POSITIVE_INFINITY;
  const maxAnswers = options.maxAnswers ?? Number.POSITIVE_INFINITY;
  const config = modeConfig(mode);
  let timeLeftMs = config.initialTimeMs;
  let usedMs = 0;
  const problems: ReplayedProblem[] = [];

  for (let index = 0; index < Math.min(answers.length, maxAnswers); index++) {
    const answer = answers[index];
    const elapsedMs = clampElapsed(answer.elapsedMs);
    if (timeLeftMs - elapsedMs < -timeoutGraceMs || usedMs + elapsedMs > maxRoundDurationMs) {
      break;
    }

    timeLeftMs -= elapsedMs;
    usedMs += elapsedMs;
    const problem = generateProblem(seed, mode, index);
    const recognized = normalizeAnswer(answer.text);
    const expected = String(problem.answer);
    const ok = recognized === expected;
    if (ok) {
      timeLeftMs = Math.min(config.maxTimeMs, Math.max(0, timeLeftMs) + config.bonusTimeMs);
    }
    problems.push({ i: index, ok, ms: elapsedMs, recognized, expected });
  }

  const score = calculateBrainScore(
    mode,
    problems.map((problem) => ({ correct: problem.ok, elapsedMs: problem.ms })),
  );

  return {
    problems,
    droppedAfterTimeout: answers.length - problems.length,
    roundDurationMs: problems.length >= maxAnswers
      ? usedMs
      : Math.min(maxRoundDurationMs, usedMs + Math.max(0, timeLeftMs)),
    score,
  };
}
