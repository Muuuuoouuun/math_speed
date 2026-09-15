import 'package:brain_math/features/game/domain/brain_score.dart';
import 'package:brain_math/features/game/domain/game_mode.dart';
import 'package:flutter_test/flutter_test.dart';

List<ProblemAttemptResult> _attempts(List<(bool, int)> pattern) {
  return [for (final (correct, elapsedMs) in pattern) ProblemAttemptResult(correct: correct, elapsedMs: elapsedMs)];
}

void main() {
  const calculator = BrainScoreCalculator();

  group('BrainScoreCalculator', () {
    test('returns an all-zero breakdown for an empty attempt list', () {
      final result = calculator.calculate(mode: GameMode.simpleCalculation, attempts: const []);
      expect(result.brainScore, 0);
      expect(result.accuracyRate, 0);
      expect(result.speedRate, 0);
      expect(result.correctPerMinute, 0);
      expect(result.basePoints, 0);
      expect(result.comboBonus, 0);
      expect(result.comboMax, 0);
      expect(result.correctCount, 0);
      expect(result.attemptCount, 0);
    });

    test('every wrong answer scores zero, and speedRate floors at 0.35', () {
      final result = calculator.calculate(
        mode: GameMode.doubleDigit,
        attempts: _attempts([(false, 100), (false, 5000), (false, 900)]),
      );
      expect(result.correctCount, 0);
      expect(result.accuracyRate, 0);
      expect(result.comboMax, 0);
      expect(result.comboBonus, 0);
      expect(result.basePoints, 0);
      expect(result.brainScore, 0);
      expect(result.correctPerMinute, 0);
      expect(result.speedRate, 0.35);
    });

    test('solving exactly at the mode target yields speedRate 1 and full accuracy weighting', () {
      final result = calculator.calculate(
        mode: GameMode.fourOperations,
        attempts: _attempts([(true, 3000), (true, 3500), (true, 3500)]),
      );
      expect(result.correctCount, 3);
      expect(result.accuracyRate, 1.0);
      expect(result.correctPerMinute, 18.0);
      expect(result.speedRate, 1.0);
      expect(result.comboMax, 3);
      expect(result.basePoints, 3 * 120 * 1.0);
      expect(result.comboBonus, 3 * (10 + GameMode.fourOperations.index * 8));
      expect(result.brainScore, (result.basePoints * result.speedRate + result.comboBonus).round());
    });

    test('speedRate is clamped to 1.35 when far faster than the mode target', () {
      final result = calculator.calculate(
        mode: GameMode.simpleCalculation,
        attempts: _attempts([for (var i = 0; i < 10; i++) (true, 100)]),
      );
      expect(result.speedRate, 1.35);
    });

    test('speedRate is clamped to 0.35 when far slower than the mode target', () {
      final result = calculator.calculate(
        mode: GameMode.simpleCalculation,
        attempts: _attempts([(true, 600000)]),
      );
      expect(result.speedRate, 0.35);
    });

    test('combo streak resets on a wrong answer and comboMax tracks the longest streak', () {
      final result = calculator.calculate(
        mode: GameMode.doubleDigit,
        attempts: _attempts([
          (true, 1700),
          (true, 1700),
          (false, 1700),
          (true, 1700),
          (true, 1700),
          (true, 1700),
        ]),
      );
      expect(result.correctCount, 5);
      expect(result.attemptCount, 6);
      expect(result.accuracyRate, 5 / 6);
      expect(result.comboMax, 3);
    });

    test('harder modes weigh correct answers more heavily, independent of speed', () {
      final pattern = _attempts([(true, 1700), (true, 1700), (false, 1700)]);
      final simple = calculator.calculate(mode: GameMode.simpleCalculation, attempts: pattern);
      final triple = calculator.calculate(mode: GameMode.tripleDigit, attempts: pattern);
      expect(simple.basePoints, 2 * 90 * (0.6 + simple.accuracyRate * 0.4));
      expect(triple.basePoints, 2 * 190 * (0.6 + triple.accuracyRate * 0.4));
      expect(triple.basePoints, greaterThan(simple.basePoints));
    });

    test('the same pace scores differently across modes because each mode targets a different pace', () {
      final pattern = _attempts([for (var i = 0; i < 4; i++) (true, 3000)]);
      final simple = calculator.calculate(mode: GameMode.simpleCalculation, attempts: pattern);
      final triple = calculator.calculate(mode: GameMode.tripleDigit, attempts: pattern);
      // simpleCalculation targets 26/min (harder to keep up with) vs tripleDigit's 10/min (easier), so
      // the identical 20/min pace reads as relatively slow for one and relatively fast for the other.
      expect(triple.speedRate, greaterThan(simple.speedRate));
    });
  });
}
