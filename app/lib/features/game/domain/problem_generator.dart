import 'deterministic_rng.dart';
import 'game_mode.dart';
import 'math_problem.dart';

class ProblemGenerator {
  const ProblemGenerator();

  // How many problems into a round it takes to reach full difficulty for the mode. Practice
  // rounds are endless (no fixed problem count), so the ramp saturates instead of resetting.
  static const int _rampLength = 14;

  MathProblem generateProblem({
    required int seed,
    required GameMode mode,
    required int index,
  }) {
    final rng = DeterministicRng(seed ^ ((mode.index + 1) * 7919) ^ ((index + 1) * 104729));
    final t = (index / _rampLength).clamp(0.0, 1.0);

    switch (mode) {
      case GameMode.simpleCalculation:
        return _simpleProblem(rng, index, t);
      case GameMode.fourOperations:
        return _fourOperationsProblem(rng, index, t);
      case GameMode.doubleDigit:
        return _doubleDigitProblem(rng, index, t);
      case GameMode.tripleDigit:
        return _tripleDigitProblem(rng, index, t);
    }
  }

  // Linearly interpolates a bound from `start` (first problem of a round) to `end` (once the
  // ramp saturates), so a round's difficulty rises gradually instead of holding one fixed range.
  int _ramp(int start, int end, double t) => (start + (end - start) * t).round();

  MathProblem _simpleProblem(DeterministicRng rng, int index, double t) {
    final isAdd = rng.nextInt(2) == 0;
    if (isAdd) {
      final a = rng.between(1, 9);
      final b = rng.between(1, 9);
      return MathProblem(index: index, level: 1, prompt: '$a + $b', answer: a + b);
    }

    final a = rng.between(5, _ramp(10, 18, t));
    final b = rng.between(1, a - 1);
    return MathProblem(index: index, level: 1, prompt: '$a - $b', answer: a - b);
  }

  MathProblem _fourOperationsProblem(DeterministicRng rng, int index, double t) {
    switch (rng.nextInt(4)) {
      case 0:
        final a = rng.between(4, _ramp(14, 24, t));
        final b = rng.between(3, _ramp(11, 19, t));
        return MathProblem(index: index, level: 2, prompt: '$a + $b', answer: a + b);
      case 1:
        final a = rng.between(12, _ramp(22, 36, t));
        final b = rng.between(3, a - 2);
        return MathProblem(index: index, level: 2, prompt: '$a - $b', answer: a - b);
      case 2:
        final a = rng.between(2, 9);
        final b = rng.between(2, 9);
        return MathProblem(index: index, level: 2, prompt: '$a x $b', answer: a * b);
      default:
        final divisor = rng.between(2, 9);
        final quotient = rng.between(2, 9);
        return MathProblem(
          index: index,
          level: 2,
          prompt: '${divisor * quotient} / $divisor',
          answer: quotient,
        );
    }
  }

  MathProblem _doubleDigitProblem(DeterministicRng rng, int index, double t) {
    switch (rng.nextInt(3)) {
      case 0:
        final a = rng.between(12, _ramp(39, 79, t));
        final b = rng.between(11, _ramp(34, 69, t));
        return MathProblem(index: index, level: 3, prompt: '$a + $b', answer: a + b);
      case 1:
        final a = rng.between(45, _ramp(69, 99, t));
        final b = rng.between(10, a - 9);
        return MathProblem(index: index, level: 3, prompt: '$a - $b', answer: a - b);
      default:
        final a = rng.between(10, _ramp(24, 49, t));
        final b = rng.between(2, 9);
        return MathProblem(index: index, level: 3, prompt: '$a x $b', answer: a * b);
    }
  }

  MathProblem _tripleDigitProblem(DeterministicRng rng, int index, double t) {
    switch (rng.nextInt(3)) {
      case 0:
        final a = rng.between(100, _ramp(299, 599, t));
        final b = rng.between(100, _ramp(249, 499, t));
        return MathProblem(index: index, level: 4, prompt: '$a + $b', answer: a + b);
      case 1:
        final a = rng.between(200, _ramp(499, 799, t));
        final b = rng.between(100, a - 50);
        return MathProblem(index: index, level: 4, prompt: '$a - $b', answer: a - b);
      default:
        final a = rng.between(100, _ramp(199, 349, t));
        final b = rng.between(2, 9);
        return MathProblem(index: index, level: 4, prompt: '$a x $b', answer: a * b);
    }
  }
}
