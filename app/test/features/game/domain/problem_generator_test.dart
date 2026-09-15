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
            const MathProblem(index: 0, level: 1, prompt: '13 - 3', answer: 10),
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
            const MathProblem(index: 0, level: 4, prompt: '351 x 8', answer: 2808),
            const MathProblem(index: 1, level: 4, prompt: '499 + 298', answer: 797),
            const MathProblem(index: 2, level: 4, prompt: '612 + 544', answer: 1156),
            const MathProblem(index: 3, level: 4, prompt: '400 x 4', answer: 1600),
            const MathProblem(index: 4, level: 4, prompt: '727 - 583', answer: 144),
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
  });
}
