export type AttemptScoreInput = {
  correct: boolean;
  elapsedMs: number;
};

export type ScoreBreakdown = {
  brainScore: number;
  accuracyRate: number;
  speedRate: number;
  basePoints: number;
  comboBonus: number;
  comboMax: number;
  correctCount: number;
};

function levelConfig(level: number): { targetSolveMs: number; maxSolveMs: number } {
  switch (level) {
    case 1:
      return { targetSolveMs: 1800, maxSolveMs: 4500 };
    case 2:
      return { targetSolveMs: 1750, maxSolveMs: 4300 };
    case 3:
      return { targetSolveMs: 1700, maxSolveMs: 4200 };
    case 4:
      return { targetSolveMs: 1650, maxSolveMs: 4000 };
    case 5:
      return { targetSolveMs: 1600, maxSolveMs: 3800 };
    case 6:
      return { targetSolveMs: 1550, maxSolveMs: 3600 };
    case 7:
      return { targetSolveMs: 1500, maxSolveMs: 3500 };
    case 8:
      return { targetSolveMs: 1450, maxSolveMs: 3400 };
    case 9:
      return { targetSolveMs: 1400, maxSolveMs: 3200 };
    default:
      return { targetSolveMs: 1350, maxSolveMs: 3000 };
  }
}

export function calculateBrainScore(level: number, attempts: AttemptScoreInput[]): ScoreBreakdown {
  if (attempts.length === 0) {
    return {
      brainScore: 0,
      accuracyRate: 0,
      speedRate: 0,
      basePoints: 0,
      comboBonus: 0,
      comboMax: 0,
      correctCount: 0,
    };
  }

  const config = levelConfig(level);
  const correctCount = attempts.filter((attempt) => attempt.correct).length;
  const accuracyRate = correctCount / attempts.length;
  const averageMs = attempts.reduce((sum, attempt) => sum + attempt.elapsedMs, 0) / attempts.length;
  const speedWindow = config.maxSolveMs - config.targetSolveMs;
  const rawSpeedRate = 1 - ((averageMs - config.targetSolveMs) / speedWindow);
  const speedRate = Math.min(1.2, Math.max(0.25, rawSpeedRate));

  let combo = 0;
  let comboMax = 0;
  for (const attempt of attempts) {
    combo = attempt.correct ? combo + 1 : 0;
    comboMax = Math.max(comboMax, combo);
  }

  const difficultyWeight = 110 + (level * 32);
  const basePoints = correctCount * difficultyWeight * (0.7 + (accuracyRate * 0.3));
  const comboBonus = comboMax * (8 + level * 2);
  const brainScore = Math.round((basePoints * speedRate) + comboBonus);

  return {
    brainScore,
    accuracyRate,
    speedRate,
    basePoints,
    comboBonus,
    comboMax,
    correctCount,
  };
}
