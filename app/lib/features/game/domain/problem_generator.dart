import 'game_mode.dart';
import 'math_problem.dart';

class DeterministicRng {
  DeterministicRng(int seed) : _state = seed == 0 ? 0x6D2B79F5 : seed & 0xFFFFFFFF;

  int _state;

  int nextInt(int maxExclusive) {
    _state ^= (_state << 13) & 0xFFFFFFFF;
    _state ^= (_state >> 17) & 0xFFFFFFFF;
    _state ^= (_state << 5) & 0xFFFFFFFF;
    final value = _state & 0x7FFFFFFF;
    return maxExclusive == 0 ? 0 : value % maxExclusive;
  }

  int between(int minInclusive, int maxInclusive) {
    return minInclusive + nextInt((maxInclusive - minInclusive) + 1);
  }
}

class ProblemGenerator {
  const ProblemGenerator();

  MathProblem generateProblem({
    required int seed,
    required GameMode mode,
    required int index,
  }) {
    final rng = DeterministicRng(seed ^ ((mode.index + 1) * 7919) ^ ((index + 1) * 104729));

    switch (mode) {
      case GameMode.simpleCalculation:
        return _simpleProblem(rng, index);
      case GameMode.fourOperations:
        return _fourOperationsProblem(rng, index);
      case GameMode.doubleDigit:
        return _doubleDigitProblem(rng, index);
      case GameMode.tripleDigit:
        return _tripleDigitProblem(rng, index);
    }
  }

  MathProblem _simpleProblem(DeterministicRng rng, int index) {
    final isAdd = rng.nextInt(2) == 0;
    if (isAdd) {
      final a = rng.between(1, 9);
      final b = rng.between(1, 9);
      return MathProblem(index: index, level: 1, prompt: '$a + $b', answer: a + b);
    }

    final a = rng.between(5, 18);
    final b = rng.between(1, a - 1);
    return MathProblem(index: index, level: 1, prompt: '$a - $b', answer: a - b);
  }

  MathProblem _fourOperationsProblem(DeterministicRng rng, int index) {
    switch (rng.nextInt(4)) {
      case 0:
        final a = rng.between(4, 24);
        final b = rng.between(3, 19);
        return MathProblem(index: index, level: 2, prompt: '$a + $b', answer: a + b);
      case 1:
        final a = rng.between(12, 36);
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

  MathProblem _doubleDigitProblem(DeterministicRng rng, int index) {
    switch (rng.nextInt(3)) {
      case 0:
        final a = rng.between(12, 79);
        final b = rng.between(11, 69);
        return MathProblem(index: index, level: 3, prompt: '$a + $b', answer: a + b);
      case 1:
        final a = rng.between(45, 99);
        final b = rng.between(10, a - 9);
        return MathProblem(index: index, level: 3, prompt: '$a - $b', answer: a - b);
      default:
        final a = rng.between(10, 49);
        final b = rng.between(2, 9);
        return MathProblem(index: index, level: 3, prompt: '$a x $b', answer: a * b);
    }
  }

  MathProblem _tripleDigitProblem(DeterministicRng rng, int index) {
    switch (rng.nextInt(3)) {
      case 0:
        final a = rng.between(120, 899);
        final b = rng.between(110, 799);
        return MathProblem(index: index, level: 4, prompt: '$a + $b', answer: a + b);
      case 1:
        final a = rng.between(320, 999);
        final b = rng.between(100, a - 50);
        return MathProblem(index: index, level: 4, prompt: '$a - $b', answer: a - b);
      default:
        final a = rng.between(100, 499);
        final b = rng.between(2, 9);
        return MathProblem(index: index, level: 4, prompt: '$a x $b', answer: a * b);
    }
  }
}
