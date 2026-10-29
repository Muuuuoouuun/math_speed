import 'dart:math' as math;

import 'package:brain_math/features/game/domain/game_mode.dart';
import 'package:brain_math/features/game/domain/math_problem.dart';
import 'package:brain_math/features/game/domain/problem_generator.dart';
import 'package:flutter_test/flutter_test.dart';

int _evaluateSimplePrompt(String prompt) {
  final parts = prompt.split(' ');
  expect(parts.length, 3, reason: 'expected "<a> <op> <b>", got "$prompt"');
  final a = int.parse(parts[0]);
  final b = int.parse(parts[2]);
  final op = parts[1];
  if (op == '+') return a + b;
  if (op == '-') return a - b;
  if (op == 'x') return a * b;
  if (op == '/') return a ~/ b;
  throw StateError('unknown operator "$op" in "$prompt"');
}

const _expectedLevel = {
  GameMode.simpleCalculation: 1,
  GameMode.fourOperations: 2,
  GameMode.doubleDigit: 3,
  GameMode.tripleDigit: 4,
};

void main() {
  const generator = ProblemGenerator();
  const seeds = [1, 42, 2024, 123456, 777777, 999999999, 0x7ffffffe];

  group('ProblemGenerator', () {
    test('is deterministic for a given seed/mode/index', () {
      for (final seed in seeds) {
        for (final mode in GameMode.values) {
          final first = generator.generateProblem(seed: seed, mode: mode, index: 3);
          final second = generator.generateProblem(seed: seed, mode: mode, index: 3);
          expect(second.prompt, first.prompt, reason: 'seed=$seed mode=$mode');
          expect(second.answer, first.answer, reason: 'seed=$seed mode=$mode');
        }
      }
    });

    test('stamps the requested index and the level that belongs to the mode', () {
      for (final mode in GameMode.values) {
        for (var index = 0; index < 15; index++) {
          final problem = generator.generateProblem(seed: 555, mode: mode, index: index);
          expect(problem.index, index);
          expect(problem.level, _expectedLevel[mode]);
        }
      }
    });

    test('every generated answer is a non-negative integer, for every mode', () {
      for (final mode in GameMode.values) {
        for (final seed in seeds) {
          for (var index = 0; index < 30; index++) {
            final problem = generator.generateProblem(seed: seed, mode: mode, index: index);
            expect(problem.answer, greaterThanOrEqualTo(0), reason: 'mode=$mode seed=$seed index=$index: ${problem.prompt}');
          }
        }
      }
    });

    test('the displayed prompt always evaluates to the stored answer', () {
      for (final mode in GameMode.values) {
        for (final seed in seeds) {
          for (var index = 0; index < 20; index++) {
            final problem = generator.generateProblem(seed: seed, mode: mode, index: index);
            expect(
              _evaluateSimplePrompt(problem.prompt),
              problem.answer,
              reason: 'mode=$mode seed=$seed index=$index: "${problem.prompt}"',
            );
          }
        }
      }
    });

    test('the division problems in fourOperations never leave a remainder', () {
      for (final seed in seeds) {
        for (var index = 0; index < 40; index++) {
          final problem = generator.generateProblem(seed: seed, mode: GameMode.fourOperations, index: index);
          if (problem.prompt.contains('/')) {
            expect(_evaluateSimplePrompt(problem.prompt) * 1.0, problem.answer * 1.0);
          }
        }
      }
    });

    test('golden vectors stay pinned across refactors', () {
      final cases = <(int, GameMode, List<MathProblem>)>[
        (
          2024,
          GameMode.simpleCalculation,
          [
            const MathProblem(index: 0, level: 1, prompt: '5 - 3', answer: 2),
            const MathProblem(index: 1, level: 1, prompt: '9 - 5', answer: 4),
            const MathProblem(index: 2, level: 1, prompt: '7 + 9', answer: 16),
            const MathProblem(index: 3, level: 1, prompt: '3 + 3', answer: 6),
            const MathProblem(index: 4, level: 1, prompt: '7 + 2', answer: 9),
          ],
        ),
        (
          2024,
          GameMode.tripleDigit,
          [
            const MathProblem(index: 0, level: 4, prompt: '151 x 8', answer: 1208),
            const MathProblem(index: 1, level: 4, prompt: '284 + 204', answer: 488),
            const MathProblem(index: 2, level: 4, prompt: '253 + 282', answer: 535),
            const MathProblem(index: 3, level: 4, prompt: '208 x 4', answer: 832),
            const MathProblem(index: 4, level: 4, prompt: '551 - 429', answer: 122),
          ],
        ),
      ];

      for (final (seed, mode, expected) in cases) {
        for (var index = 0; index < expected.length; index++) {
          final problem = generator.generateProblem(seed: seed, mode: mode, index: index);
          expect(problem.prompt, expected[index].prompt, reason: 'seed=$seed mode=$mode index=$index');
          expect(problem.answer, expected[index].answer, reason: 'seed=$seed mode=$mode index=$index');
        }
      }
    });

    test('difficulty ramps up over a round: the reachable ceiling grows before it saturates', () {
      // The round-endless ramp saturates after a fixed warm-up (index 14), so comparing two
      // *individual* problems is noisy - about half of every mode's branches (a fixed-range
      // multiply/divide, or fourOperations' un-ramped table facts) don't scale with the ramp
      // at all. Instead, sweep many seeds at a fixed index and take the observed max: since the
      // ramped branches' range is strictly wider once saturated, the ceiling observed across
      // enough seeds must be higher post-ramp than at index 0, even though any single problem
      // may land anywhere in its (possibly still-narrow) range.
      int maxOperand(String prompt) {
        final numbers = RegExp(r'\d+').allMatches(prompt).map((m) => int.parse(m.group(0)!));
        return numbers.reduce((a, b) => a > b ? a : b);
      }

      bool isAddOrSub(String prompt) => prompt.contains(' + ') || prompt.contains(' - ');

      const sweepSeeds = 40;
      const saturatedIndex = 30; // well past the ramp's 14-problem warm-up window

      for (final mode in GameMode.values) {
        var maxAtStart = -1;
        var maxAtSaturated = -1;
        for (var seed = 1; seed <= sweepSeeds; seed++) {
          final start = generator.generateProblem(seed: seed, mode: mode, index: 0);
          final saturated = generator.generateProblem(seed: seed, mode: mode, index: saturatedIndex);
          // fourOperations' un-ramped multiply/divide branches (always 2-9) can otherwise mask
          // the ramp on its add/subtract branches, since 9x9=81 exceeds their starting ceiling.
          if (mode == GameMode.fourOperations) {
            if (isAddOrSub(start.prompt)) maxAtStart = math.max(maxAtStart, maxOperand(start.prompt));
            if (isAddOrSub(saturated.prompt)) maxAtSaturated = math.max(maxAtSaturated, maxOperand(saturated.prompt));
          } else {
            maxAtStart = math.max(maxAtStart, maxOperand(start.prompt));
            maxAtSaturated = math.max(maxAtSaturated, maxOperand(saturated.prompt));
          }
        }
        expect(
          maxAtSaturated,
          greaterThan(maxAtStart),
          reason: 'mode=$mode: expected the ceiling reachable at index $saturatedIndex to exceed index 0\'s',
        );
      }
    });
  });
}
