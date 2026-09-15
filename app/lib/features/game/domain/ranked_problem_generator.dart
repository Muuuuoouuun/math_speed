import 'dart:math' as math;

import 'deterministic_rng.dart';
import 'math_problem.dart';

/// Mirrors functions/src/mathEngine.ts exactly (same RNG, same per-level shapes,
/// same non-negative/exact-division guarantees) so a ranked session's seed produces
/// the identical problem set on this client as the server uses to grade it.
class RankedProblemGenerator {
  const RankedProblemGenerator();

  List<MathProblem> generateSessionProblems({
    required int seed,
    required int level,
    required int count,
  }) {
    final rng = DeterministicRng((seed ^ (level * 7919) ^ (count * 104729)) & 0xFFFFFFFF);
    return List<MathProblem>.generate(count, (index) => _buildProblem(rng, level, index));
  }

  MathProblem _buildProblem(DeterministicRng rng, int level, int index) {
    switch (level) {
      case 1:
        return _singleDigitAdd(rng, level, index);
      case 2:
        return _within20Mix(rng, level, index);
      case 3:
        return _twoDigitMix(rng, level, index);
      case 4:
        return _carryPlusTable(rng, level, index);
      case 5:
        return _tableMultiplication(rng, level, index);
      case 6:
        return _exactDivision(rng, level, index);
      case 7:
        return _twoStepMixed(rng, level, index);
      case 8:
        return _threeNumberMixed(rng, level, index);
      case 9:
        return _multiMultiplyDivide(rng, level, index);
      default:
        return _bossRound(rng, level, index);
    }
  }

  MathProblem _singleDigitAdd(DeterministicRng rng, int level, int index) {
    final a = rng.between(1, 9);
    final b = rng.between(1, 9);
    return MathProblem(index: index, level: level, prompt: '$a + $b', answer: a + b);
  }

  MathProblem _within20Mix(DeterministicRng rng, int level, int index) {
    final add = rng.nextInt(2) == 0;
    if (add) {
      final a = rng.between(3, 15);
      final b = rng.between(1, 20 - a);
      return MathProblem(index: index, level: level, prompt: '$a + $b', answer: a + b);
    }

    final a = rng.between(8, 20);
    final b = rng.between(1, a - 1);
    return MathProblem(index: index, level: level, prompt: '$a - $b', answer: a - b);
  }

  MathProblem _twoDigitMix(DeterministicRng rng, int level, int index) {
    final add = rng.nextInt(2) == 0;
    if (add) {
      final a = rng.between(11, 59);
      final b = rng.between(11, 39);
      return MathProblem(index: index, level: level, prompt: '$a + $b', answer: a + b);
    }

    final a = rng.between(30, 99);
    final b = rng.between(10, a - 5);
    return MathProblem(index: index, level: level, prompt: '$a - $b', answer: a - b);
  }

  MathProblem _carryPlusTable(DeterministicRng rng, int level, int index) {
    if (rng.nextInt(3) == 0) {
      final a = rng.between(2, 9);
      final b = rng.between(3, 9);
      return MathProblem(index: index, level: level, prompt: '$a × $b', answer: a * b);
    }

    final a = rng.between(28, 87);
    final b = rng.between(15, 38);
    return MathProblem(index: index, level: level, prompt: '$a + $b', answer: a + b);
  }

  MathProblem _tableMultiplication(DeterministicRng rng, int level, int index) {
    final a = rng.between(3, 12);
    final b = rng.between(3, 12);
    return MathProblem(index: index, level: level, prompt: '$a × $b', answer: a * b);
  }

  MathProblem _exactDivision(DeterministicRng rng, int level, int index) {
    final divisor = rng.between(2, 12);
    final quotient = rng.between(2, 12);
    final dividend = divisor * quotient;
    return MathProblem(index: index, level: level, prompt: '$dividend ÷ $divisor', answer: quotient);
  }

  MathProblem _twoStepMixed(DeterministicRng rng, int level, int index) {
    final left = rng.between(2, 9);
    final right = rng.between(2, 9);
    final tail = rng.between(5, 40);
    final multiplyFirst = rng.nextInt(2) == 0;

    if (multiplyFirst) {
      return MathProblem(
        index: index,
        level: level,
        prompt: '($left × $right) + $tail',
        answer: (left * right) + tail,
      );
    }

    // tail + left - right stays non-negative for every draw (grade 1-6 math never expects signed results).
    final bigger = math.max(left, right);
    final smaller = math.min(left, right);
    return MathProblem(
      index: index,
      level: level,
      prompt: '$tail + $bigger - $smaller',
      answer: tail + bigger - smaller,
    );
  }

  MathProblem _threeNumberMixed(DeterministicRng rng, int level, int index) {
    final a = rng.between(15, 99);
    final b = rng.between(5, 39);
    final addLast = rng.nextInt(2) == 0;

    if (addLast) {
      final bigger = math.max(a, b);
      final smaller = math.min(a, b);
      final c = rng.between(3, 25);
      return MathProblem(
        index: index,
        level: level,
        prompt: '$bigger - $smaller + $c',
        answer: (bigger - smaller) + c,
      );
    }

    // Bound c by a + b so a + b - c never goes negative; a + b is at least 20, so this stays >= 3.
    final maxC = math.min(25, a + b - 1);
    final c = rng.between(3, maxC);
    return MathProblem(index: index, level: level, prompt: '$a + $b - $c', answer: a + b - c);
  }

  MathProblem _multiMultiplyDivide(DeterministicRng rng, int level, int index) {
    final a = rng.between(3, 12);
    final c = rng.between(2, 6);
    // Pick b as a multiple of c/gcd(a, c) so c divides (a x b) exactly, matching _exactDivision's guarantee.
    final step = c ~/ _gcd(a, c);
    final multiplier = rng.between(1, 4);
    final b = step * multiplier;
    return MathProblem(index: index, level: level, prompt: '($a × $b) ÷ $c', answer: (a * b) ~/ c);
  }

  MathProblem _bossRound(DeterministicRng rng, int level, int index) {
    final a = rng.between(12, 29);
    final b = rng.between(4, 12);
    final c = rng.between(3, 9);
    final d = rng.between(10, 49);
    final firstProduct = a * b;
    final secondProduct = c * d;
    // Display the larger product first so the subtraction never goes negative.
    final useFirstAsMinuend = firstProduct >= secondProduct;
    final minuendLeft = useFirstAsMinuend ? a : c;
    final minuendRight = useFirstAsMinuend ? b : d;
    final subtrahendLeft = useFirstAsMinuend ? c : a;
    final subtrahendRight = useFirstAsMinuend ? d : b;
    final minuendProduct = useFirstAsMinuend ? firstProduct : secondProduct;
    final subtrahendProduct = useFirstAsMinuend ? secondProduct : firstProduct;
    return MathProblem(
      index: index,
      level: level,
      prompt: '($minuendLeft × $minuendRight) - ($subtrahendLeft × $subtrahendRight)',
      answer: minuendProduct - subtrahendProduct,
    );
  }

  int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);
}
