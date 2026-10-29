import 'package:brain_math/features/game/domain/math_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MathLevelConfig.fromLevel', () {
    test('exposes the level field the caller asked for', () {
      for (var level = 1; level <= 10; level++) {
        expect(MathLevelConfig.fromLevel(level).level, level);
      }
    });

    test('level 11 and above fall back to the level 10 (boss) tuning', () {
      final level10 = MathLevelConfig.fromLevel(10);
      final level99 = MathLevelConfig.fromLevel(99);
      expect(level99.problemCount, level10.problemCount);
      expect(level99.targetSolveMs, level10.targetSolveMs);
      expect(level99.maxSolveMs, level10.maxSolveMs);
    });

    test('multi-step levels are given more time than single-operation ones', () {
      // The pace is fitted to each level's problem shape, so it is deliberately not monotonic in
      // the level number - levels 5-6 are a single times-table fact and are quicker than level 4's
      // two-digit carrying. What must hold is that the compound levels, which genuinely take
      // longer to work through, are never asked to be solved faster than the one-step levels.
      final singleStep = [1, 2, 5, 6].map(MathLevelConfig.fromLevel);
      final multiStep = [7, 8, 9, 10].map(MathLevelConfig.fromLevel);
      final slowestSingleStep = singleStep.map((c) => c.targetSolveMs).reduce((a, b) => a > b ? a : b);
      final quickestMultiStep = multiStep.map((c) => c.targetSolveMs).reduce((a, b) => a < b ? a : b);
      expect(quickestMultiStep, greaterThan(slowestSingleStep));
    });

    test('every level leaves room between its target and max pace', () {
      // maxSolveMs is what the speed multiplier measures against; if it crowds targetSolveMs the
      // multiplier pins to its floor and speed stops being a scoring signal at that level.
      for (var level = 1; level <= 10; level++) {
        final config = MathLevelConfig.fromLevel(level);
        expect(
          config.maxSolveMs,
          greaterThan(config.targetSolveMs * 2),
          reason: 'level $level leaves too little headroom above its target pace',
        );
      }
    });

    // Mirrors functions/src/scoring.ts's levelConfig() and index.ts's problemCountForLevel()
    // exactly, so a local practice-mode pacing readout matches what the ranked server grades.
    test('matches the server-side per-level tuning exactly', () {
      final expected = {
        1: (problemCount: 10, targetSolveMs: 1500, maxSolveMs: 3600),
        2: (problemCount: 10, targetSolveMs: 1600, maxSolveMs: 3800),
        3: (problemCount: 12, targetSolveMs: 2000, maxSolveMs: 4600),
        4: (problemCount: 12, targetSolveMs: 2500, maxSolveMs: 5800),
        5: (problemCount: 14, targetSolveMs: 1800, maxSolveMs: 4200),
        6: (problemCount: 14, targetSolveMs: 1850, maxSolveMs: 4300),
        7: (problemCount: 16, targetSolveMs: 2700, maxSolveMs: 6200),
        8: (problemCount: 16, targetSolveMs: 2900, maxSolveMs: 6600),
        9: (problemCount: 18, targetSolveMs: 3000, maxSolveMs: 6900),
        10: (problemCount: 20, targetSolveMs: 4000, maxSolveMs: 9000),
      };

      expected.forEach((level, expectedValues) {
        final config = MathLevelConfig.fromLevel(level);
        expect(config.problemCount, expectedValues.problemCount, reason: 'level $level problemCount');
        expect(config.targetSolveMs, expectedValues.targetSolveMs, reason: 'level $level targetSolveMs');
        expect(config.maxSolveMs, expectedValues.maxSolveMs, reason: 'level $level maxSolveMs');
      });
    });
  });
}
