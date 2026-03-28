class MathLevelConfig {
  const MathLevelConfig({
    required this.level,
    required this.problemCount,
    required this.targetSolveMs,
    required this.maxSolveMs,
  });

  final int level;
  final int problemCount;
  final int targetSolveMs;
  final int maxSolveMs;

  static MathLevelConfig fromLevel(int level) {
    switch (level) {
      case 1:
        return const MathLevelConfig(level: 1, problemCount: 10, targetSolveMs: 1800, maxSolveMs: 4500);
      case 2:
        return const MathLevelConfig(level: 2, problemCount: 10, targetSolveMs: 1750, maxSolveMs: 4300);
      case 3:
        return const MathLevelConfig(level: 3, problemCount: 12, targetSolveMs: 1700, maxSolveMs: 4200);
      case 4:
        return const MathLevelConfig(level: 4, problemCount: 12, targetSolveMs: 1650, maxSolveMs: 4000);
      case 5:
        return const MathLevelConfig(level: 5, problemCount: 14, targetSolveMs: 1600, maxSolveMs: 3800);
      case 6:
        return const MathLevelConfig(level: 6, problemCount: 14, targetSolveMs: 1550, maxSolveMs: 3600);
      case 7:
        return const MathLevelConfig(level: 7, problemCount: 16, targetSolveMs: 1500, maxSolveMs: 3500);
      case 8:
        return const MathLevelConfig(level: 8, problemCount: 16, targetSolveMs: 1450, maxSolveMs: 3400);
      case 9:
        return const MathLevelConfig(level: 9, problemCount: 18, targetSolveMs: 1400, maxSolveMs: 3200);
      default:
        return const MathLevelConfig(level: 10, problemCount: 20, targetSolveMs: 1350, maxSolveMs: 3000);
    }
  }
}

