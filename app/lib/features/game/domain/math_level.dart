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

  /// Mirrors functions/src/scoring.ts's levelConfig() and index.ts's problemCountForLevel().
  /// Each level's pace is fitted to how long its own problem shape actually takes to solve and
  /// hand-write, so levels 5-6 (a times-table fact) are quicker than level 4 (two-digit carrying).
  static MathLevelConfig fromLevel(int level) {
    switch (level) {
      case 1:
        return const MathLevelConfig(level: 1, problemCount: 10, targetSolveMs: 1500, maxSolveMs: 3600);
      case 2:
        return const MathLevelConfig(level: 2, problemCount: 10, targetSolveMs: 1600, maxSolveMs: 3800);
      case 3:
        return const MathLevelConfig(level: 3, problemCount: 12, targetSolveMs: 2000, maxSolveMs: 4600);
      case 4:
        return const MathLevelConfig(level: 4, problemCount: 12, targetSolveMs: 2500, maxSolveMs: 5800);
      case 5:
        return const MathLevelConfig(level: 5, problemCount: 14, targetSolveMs: 1800, maxSolveMs: 4200);
      case 6:
        return const MathLevelConfig(level: 6, problemCount: 14, targetSolveMs: 1850, maxSolveMs: 4300);
      case 7:
        return const MathLevelConfig(level: 7, problemCount: 16, targetSolveMs: 2700, maxSolveMs: 6200);
      case 8:
        return const MathLevelConfig(level: 8, problemCount: 16, targetSolveMs: 2900, maxSolveMs: 6600);
      case 9:
        return const MathLevelConfig(level: 9, problemCount: 18, targetSolveMs: 3000, maxSolveMs: 6900);
      default:
        return const MathLevelConfig(level: 10, problemCount: 20, targetSolveMs: 4000, maxSolveMs: 9000);
    }
  }
}

