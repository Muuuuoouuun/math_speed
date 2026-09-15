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

    // Mirrors functions/src/scoring.ts's levelConfig() and index.ts's problemCountForLevel()
    // exactly, so a local practice-mode pacing readout matches what the ranked server grades.
    test('matches the server-side per-level tuning exactly', () {
      final expected = {
        1: (problemCount: 10, targetSolveMs: 1800, maxSolveMs: 4500),
        2: (problemCount: 10, targetSolveMs: 1750, maxSolveMs: 4300),
        3: (problemCount: 12, targetSolveMs: 1700, maxSolveMs: 4200),
        4: (problemCount: 12, targetSolveMs: 1650, maxSolveMs: 4000),
        5: (problemCount: 14, targetSolveMs: 1600, maxSolveMs: 3800),
        6: (problemCount: 14, targetSolveMs: 1550, maxSolveMs: 3600),
        7: (problemCount: 16, targetSolveMs: 1500, maxSolveMs: 3500),
        8: (problemCount: 16, targetSolveMs: 1450, maxSolveMs: 3400),
        9: (problemCount: 18, targetSolveMs: 1400, maxSolveMs: 3200),
        10: (problemCount: 20, targetSolveMs: 1350, maxSolveMs: 3000),
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
