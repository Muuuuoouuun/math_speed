import 'math_problem.dart';
import 'problem_generator.dart' show DeterministicRng;

/// 랭크전 문제 생성기.
///
/// 서버(`functions/src/mathEngine.ts`)의 `generateSessionProblems`를 그대로
/// 옮긴 것입니다. 랭크전은 클라이언트가 푼 문제를 서버가 같은 시드로 다시 만들어
/// 채점하기 때문에, 두 구현이 한 글자라도 어긋나면 모든 답이 오답 처리됩니다.
///
/// 그래서 이 파일은 "예쁘게 다듬는" 대신 서버 코드와 1:1로 대응하도록 두고,
/// `test/ranked_problem_generator_test.dart`가 실제 서버 엔진에서 뽑은 값과
/// 대조합니다. 한쪽을 고치면 반드시 다른 쪽도 같이 고쳐야 합니다.
class RankedProblemGenerator {
  const RankedProblemGenerator();

  /// 한 판에 나올 문제를 순서대로 만듭니다.
  ///
  /// 연습 모드와 달리 난수 생성기를 문제마다 새로 만들지 않고, 판 전체에서
  /// 하나를 이어 씁니다. 서버가 그렇게 하기 때문입니다.
  List<MathProblem> generateSession({
    required int seed,
    required int level,
    required int count,
  }) {
    final rng = DeterministicRng(
      (seed ^ (level * 7919) ^ (count * 104729)) & 0xFFFFFFFF,
    );
    return List<MathProblem>.generate(
      count,
      (index) => _build(rng, level, index),
      growable: false,
    );
  }

  MathProblem _build(DeterministicRng rng, int level, int index) {
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

    return MathProblem(
      index: index,
      level: level,
      prompt: '$tail + $left - $right',
      answer: tail + left - right,
    );
  }

  MathProblem _threeNumberMixed(DeterministicRng rng, int level, int index) {
    final a = rng.between(15, 99);
    final b = rng.between(5, 39);
    final c = rng.between(3, 25);
    final addLast = rng.nextInt(2) == 0;
    final answer = addLast ? (a - b) + c : (a + b) - c;
    final prompt = addLast ? '$a - $b + $c' : '$a + $b - $c';
    return MathProblem(index: index, level: level, prompt: prompt, answer: answer);
  }

  MathProblem _multiMultiplyDivide(DeterministicRng rng, int level, int index) {
    final a = rng.between(3, 12);
    final b = rng.between(3, 12);
    final c = rng.between(2, 6);
    return MathProblem(
      index: index,
      level: level,
      prompt: '($a × $b) ÷ $c',
      answer: (a * b) ~/ c,
    );
  }

  MathProblem _bossRound(DeterministicRng rng, int level, int index) {
    final a = rng.between(12, 29);
    final b = rng.between(4, 12);
    final c = rng.between(3, 9);
    final d = rng.between(10, 49);
    return MathProblem(
      index: index,
      level: level,
      prompt: '($a × $b) - ($c × $d)',
      answer: (a * b) - (c * d),
    );
  }
}
