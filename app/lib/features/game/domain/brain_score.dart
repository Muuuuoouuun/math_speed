import 'dart:math' as math;

import 'game_mode.dart';

class ProblemAttemptResult {
  const ProblemAttemptResult({
    required this.correct,
    required this.elapsedMs,
  });

  final bool correct;
  final int elapsedMs;
}

class BrainScoreBreakdown {
  const BrainScoreBreakdown({
    required this.brainScore,
    required this.accuracyRate,
    required this.speedRate,
    required this.correctPerMinute,
    required this.basePoints,
    required this.comboBonus,
    required this.comboMax,
    required this.correctCount,
    required this.attemptCount,
  });

  final int brainScore;
  final double accuracyRate;
  final double speedRate;
  final double correctPerMinute;
  final double basePoints;
  final int comboBonus;
  final int comboMax;
  final int correctCount;
  final int attemptCount;
}

class BrainScoreCalculator {
  const BrainScoreCalculator();

  BrainScoreBreakdown calculate({
    required GameMode mode,
    required List<ProblemAttemptResult> attempts,
  }) {
    if (attempts.isEmpty) {
      return const BrainScoreBreakdown(
        brainScore: 0,
        accuracyRate: 0,
        speedRate: 0,
        correctPerMinute: 0,
        basePoints: 0,
        comboBonus: 0,
        comboMax: 0,
        correctCount: 0,
        attemptCount: 0,
      );
    }

    final config = GameModeConfig.fromMode(mode);
    final total = attempts.length;
    final correctCount = attempts.where((attempt) => attempt.correct).length;
    final accuracyRate = correctCount / total;
    final elapsedTotal = attempts
        .map((attempt) => attempt.elapsedMs)
        .reduce((left, right) => left + right);
    final correctPerMinute = correctCount == 0 ? 0.0 : correctCount / (elapsedTotal / 60000);
    final speedRate = (correctPerMinute / config.targetCorrectPerMinute).clamp(0.35, 1.35);

    var combo = 0;
    var comboMax = 0;
    for (final attempt in attempts) {
      combo = attempt.correct ? combo + 1 : 0;
      comboMax = math.max(comboMax, combo);
    }

    final difficultyWeight = switch (mode) {
      GameMode.simpleCalculation => 90,
      GameMode.fourOperations => 120,
      GameMode.doubleDigit => 150,
      GameMode.tripleDigit => 190,
    };
    final basePoints = correctCount * difficultyWeight * (0.6 + (accuracyRate * 0.4));
    final comboBonus = comboMax * (10 + (mode.index * 8));
    final finalScore = ((basePoints * speedRate) + comboBonus).round();

    return BrainScoreBreakdown(
      brainScore: finalScore,
      accuracyRate: accuracyRate,
      speedRate: speedRate.toDouble(),
      correctPerMinute: correctPerMinute,
      basePoints: basePoints,
      comboBonus: comboBonus,
      comboMax: comboMax,
      correctCount: correctCount,
      attemptCount: total,
    );
  }
}
