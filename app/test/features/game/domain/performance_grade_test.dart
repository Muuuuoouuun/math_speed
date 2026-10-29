import 'package:brain_math/features/game/domain/game_mode.dart';
import 'package:brain_math/features/game/domain/performance_grade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const grader = PerformanceGrader();

  group('PerformanceGrader', () {
    test('falls back to turtle when nothing was attempted', () {
      final grade = grader.grade(
        mode: GameMode.simpleCalculation,
        correctCount: 0,
        attemptCount: 0,
        elapsedMs: 5000,
      );
      expect(grade.label, '거북이');
    });

    test('falls back to turtle when elapsed time is not positive', () {
      final grade = grader.grade(
        mode: GameMode.simpleCalculation,
        correctCount: 5,
        attemptCount: 5,
        elapsedMs: 0,
      );
      expect(grade.label, '거북이');
    });

    test('perfect accuracy at a much faster pace than the target earns cheetah', () {
      final grade = grader.grade(
        mode: GameMode.simpleCalculation,
        correctCount: 10,
        attemptCount: 10,
        elapsedMs: 6000,
      );
      expect(grade.label, '치타');
    });

    test('perfect accuracy at exactly the target pace earns rocket, not cheetah', () {
      final grade = grader.grade(
        mode: GameMode.simpleCalculation,
        correctCount: 26,
        attemptCount: 26,
        elapsedMs: 60000,
      );
      expect(grade.label, '로켓');
    });

    test('solid accuracy at the target pace earns car', () {
      final grade = grader.grade(
        mode: GameMode.fourOperations,
        correctCount: 18,
        attemptCount: 21,
        elapsedMs: 60000,
      );
      expect(grade.label, '자동차');
    });

    test('moderate accuracy at a below-target pace earns bike', () {
      final grade = grader.grade(
        mode: GameMode.fourOperations,
        correctCount: 16,
        attemptCount: 20,
        elapsedMs: 76000,
      );
      expect(grade.label, '자전거');
    });

    test('lower accuracy at a slow pace earns walker', () {
      final grade = grader.grade(
        mode: GameMode.fourOperations,
        correctCount: 13,
        attemptCount: 20,
        elapsedMs: 90000,
      );
      expect(grade.label, '뚜벅이');
    });

    test('low accuracy stays turtle even with plenty of time to answer', () {
      final grade = grader.grade(
        mode: GameMode.simpleCalculation,
        correctCount: 3,
        attemptCount: 10,
        elapsedMs: 60000,
      );
      expect(grade.label, '거북이');
    });

    test('a blistering pace cannot buy a tier that low accuracy has not earned', () {
      // Accuracy gates every tier: even the fastest possible pace cannot push a 30%
      // accuracy run past turtle, because every higher tier also demands >= 0.62 accuracy.
      final grade = grader.grade(
        mode: GameMode.simpleCalculation,
        correctCount: 3,
        attemptCount: 10,
        elapsedMs: 1,
      );
      expect(grade.label, '거북이');
    });
  });
}
