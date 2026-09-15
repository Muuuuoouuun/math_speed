import 'dart:math' as math;

import 'deterministic_rng.dart';
import 'math_problem.dart';

/// Mirrors functions/src/mathEngine.ts exactly (same RNG, same per-level shapes,
/// same non-negative/exact-division guarantees, same within-session ramp) so a ranked
/// session's seed produces the identical problem set on this client as the server uses
/// to grade it.
class RankedProblemGenerator {
  const RankedProblemGenerator();

  List<MathProblem> generateSessionProblems({
    required int seed,
    required int level,
    required int count,
  }) {
    final rng = DeterministicRng((seed ^ (level * 7919) ^ (count * 104729)) & 0xFFFFFFFF);
    return List<MathProblem>.generate(count, (index) {
      final t = count <= 1 ? 0.0 : index / (count - 1);
      return _buildProblem(rng, level, index, t);
    });
  }

  // Linearly interpolates a bound from `start` (first problem of a session) to `end` (last
  // problem), so a session's difficulty ramps up gradually instead of holding one fixed range
  // for every problem at a given level.
  int _ramp(int start, int end, double t) => (start + (end - start) * t).round();

  MathProblem _buildProblem(DeterministicRng rng, int level, int index, double t) {
    switch (level) {
      case 1:
        return _singleDigitAdd(rng, level, index, t);
      case 2:
        return _within20Mix(rng, level, index, t);
      case 3:
        return _twoDigitMix(rng, level, index, t);
      case 4:
        return _twoDigitFull(rng, level, index, t);
      case 5:
        return _tableMultiplication(rng, level, index, t);
      case 6:
        return _exactDivision(rng, level, index, t);
      case 7:
        return _twoStepMixed(rng, level, index, t);
      case 8:
        return _threeNumberMixed(rng, level, index, t);
      case 9:
        return _multiMultiplyDivide(rng, level, index, t);
      default:
        return _bossRound(rng, level, index, t);
    }
  }

  MathProblem _singleDigitAdd(DeterministicRng rng, int level, int index, double t) {
    final a = rng.between(1, 9);
    final b = rng.between(1, _ramp(5, 9, t));
    return MathProblem(index: index, level: level, prompt: '$a + $b', answer: a + b);
  }

  MathProblem _within20Mix(DeterministicRng rng, int level, int index, double t) {
    final add = rng.nextInt(2) == 0;
    if (add) {
      final a = rng.between(3, _ramp(9, 15, t));
      final b = rng.between(1, 20 - a);
      return MathProblem(index: index, level: level, prompt: '$a + $b', answer: a + b);
    }

    final a = rng.between(8, _ramp(14, 20, t));
    final b = rng.between(1, a - 1);
    return MathProblem(index: index, level: level, prompt: '$a - $b', answer: a - b);
  }

  MathProblem _twoDigitMix(DeterministicRng rng, int level, int index, double t) {
    final add = rng.nextInt(2) == 0;
    if (add) {
      final a = rng.between(10, _ramp(19, 34, t));
      final b = rng.between(10, _ramp(19, 29, t));
      return MathProblem(index: index, level: level, prompt: '$a + $b', answer: a + b);
    }

    final a = rng.between(20, _ramp(34, 54, t));
    final b = rng.between(10, a - 5);
    return MathProblem(index: index, level: level, prompt: '$a - $b', answer: a - b);
  }

  MathProblem _twoDigitFull(DeterministicRng rng, int level, int index, double t) {
    final add = rng.nextInt(2) == 0;
    if (add) {
      final a = rng.between(35, _ramp(59, 89, t));
      final b = rng.between(25, _ramp(49, 69, t));
      return MathProblem(index: index, level: level, prompt: '$a + $b', answer: a + b);
    }

    final a = rng.between(50, _ramp(79, 99, t));
    final b = rng.between(20, a - 15);
    return MathProblem(index: index, level: level, prompt: '$a - $b', answer: a - b);
  }

  MathProblem _tableMultiplication(DeterministicRng rng, int level, int index, double t) {
    final a = rng.between(2, _ramp(5, 9, t));
    final b = rng.between(2, 9);
    return MathProblem(index: index, level: level, prompt: '$a × $b', answer: a * b);
  }

  MathProblem _exactDivision(DeterministicRng rng, int level, int index, double t) {
    final divisor = rng.between(2, _ramp(5, 9, t));
    final quotient = rng.between(2, 9);
    final dividend = divisor * quotient;
    return MathProblem(index: index, level: level, prompt: '$dividend ÷ $divisor', answer: quotient);
  }

  MathProblem _twoStepMixed(DeterministicRng rng, int level, int index, double t) {
    final left = rng.between(2, 9);
    final right = rng.between(2, 9);
    final tail = rng.between(5, _ramp(15, 30, t));
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

  MathProblem _threeNumberMixed(DeterministicRng rng, int level, int index, double t) {
    final a = rng.between(10, _ramp(29, 49, t));
    final b = rng.between(5, _ramp(19, 29, t));
    final addLast = rng.nextInt(2) == 0;

    if (addLast) {
      final bigger = math.max(a, b);
      final smaller = math.min(a, b);
      final c = rng.between(3, _ramp(9, 19, t));
      return MathProblem(
        index: index,
        level: level,
        prompt: '$bigger - $smaller + $c',
        answer: (bigger - smaller) + c,
      );
    }

    // Bound c by a + b so a + b - c never goes negative.
    final maxC = math.min(_ramp(9, 19, t), a + b - 1);
    final c = rng.between(3, maxC);
    return MathProblem(index: index, level: level, prompt: '$a + $b - $c', answer: a + b - c);
  }

  MathProblem _multiMultiplyDivide(DeterministicRng rng, int level, int index, double t) {
    final a = rng.between(2, 9);
    final c = rng.between(2, 6);
    // Pick b as a multiple of c/gcd(a, c) so c divides (a x b) exactly, matching _exactDivision's guarantee.
    final step = c ~/ _gcd(a, c);
    final multiplier = rng.between(1, _ramp(2, 4, t));
    final b = step * multiplier;
    return MathProblem(index: index, level: level, prompt: '($a × $b) ÷ $c', answer: (a * b) ~/ c);
  }

  MathProblem _bossRound(DeterministicRng rng, int level, int index, double t) {
    final a = rng.between(10, _ramp(15, 24, t));
    final b = rng.between(4, _ramp(7, 12, t));
    final c = rng.between(2, _ramp(4, 8, t));
    final d = rng.between(8, _ramp(15, 29, t));
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
