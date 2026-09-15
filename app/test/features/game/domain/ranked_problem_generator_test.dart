import 'package:brain_math/features/game/domain/math_problem.dart';
import 'package:brain_math/features/game/domain/ranked_problem_generator.dart';
import 'package:flutter_test/flutter_test.dart';

const _allLevels = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
const _seeds = [1, 42, 2024, 123456, 777777, 999999999, 0x7ffffffe];

void main() {
  const generator = RankedProblemGenerator();

  group('RankedProblemGenerator', () {
    test('is deterministic for a given seed/level/count', () {
      for (final seed in _seeds) {
        for (final level in _allLevels) {
          final first = generator.generateSessionProblems(seed: seed, level: level, count: 12);
          final second = generator.generateSessionProblems(seed: seed, level: level, count: 12);
          for (var i = 0; i < first.length; i++) {
            expect(second[i].prompt, first[i].prompt, reason: 'seed=$seed level=$level index=$i');
            expect(second[i].answer, first[i].answer, reason: 'seed=$seed level=$level index=$i');
          }
        }
      }
    });

    test('returns problems with sequential indices and the requested level', () {
      final problems = generator.generateSessionProblems(seed: 555, level: 4, count: 9);
      expect(problems.length, 9);
      for (var i = 0; i < problems.length; i++) {
        expect(problems[i].index, i);
        expect(problems[i].level, 4);
      }
    });

    test('every generated answer is a non-negative integer, for every level', () {
      for (final level in _allLevels) {
        for (final seed in _seeds) {
          final problems = generator.generateSessionProblems(seed: seed, level: level, count: 30);
          for (final problem in problems) {
            expect(problem.answer, greaterThanOrEqualTo(0), reason: 'level=$level seed=$seed: ${problem.prompt}');
          }
        }
      }
    });

    test('level 6 (exact division) computes an exact quotient', () {
      final pattern = RegExp(r'^(\d+) ÷ (\d+)$');
      for (final seed in _seeds) {
        final problems = generator.generateSessionProblems(seed: seed, level: 6, count: 25);
        for (final problem in problems) {
          final match = pattern.firstMatch(problem.prompt);
          expect(match, isNotNull, reason: 'unexpected level 6 prompt shape: ${problem.prompt}');
          final dividend = int.parse(match!.group(1)!);
          final divisor = int.parse(match.group(2)!);
          expect(problem.answer * divisor, dividend, reason: problem.prompt);
        }
      }
    });

    test('level 9 (multi multiply-divide) computes an exact quotient', () {
      final pattern = RegExp(r'^\((\d+) × (\d+)\) ÷ (\d+)$');
      for (final seed in _seeds) {
        final problems = generator.generateSessionProblems(seed: seed, level: 9, count: 25);
        for (final problem in problems) {
          final match = pattern.firstMatch(problem.prompt);
          expect(match, isNotNull, reason: 'unexpected level 9 prompt shape: ${problem.prompt}');
          final a = int.parse(match!.group(1)!);
          final b = int.parse(match.group(2)!);
          final c = int.parse(match.group(3)!);
          expect(a * b, problem.answer * c, reason: problem.prompt);
        }
      }
    });

    test('level 10 (boss round) always subtracts the smaller product from the larger one', () {
      final pattern = RegExp(r'^\((\d+) × (\d+)\) - \((\d+) × (\d+)\)$');
      for (final seed in _seeds) {
        final problems = generator.generateSessionProblems(seed: seed, level: 10, count: 25);
        for (final problem in problems) {
          final match = pattern.firstMatch(problem.prompt);
          expect(match, isNotNull, reason: 'unexpected boss round prompt shape: ${problem.prompt}');
          final a = int.parse(match!.group(1)!);
          final b = int.parse(match.group(2)!);
          final c = int.parse(match.group(3)!);
          final d = int.parse(match.group(4)!);
          expect(a * b, greaterThanOrEqualTo(c * d), reason: 'expected the first product to be >= the second in "${problem.prompt}"');
          expect(problem.answer, (a * b) - (c * d));
        }
      }
    });

    test('matches functions/src/mathEngine.ts exactly for the same seed (client/server parity)', () {
      final cases = <(int, int, int, List<MathProblem>)>[
        (
          2024,
          1,
          5,
          [
            const MathProblem(index: 0, level: 1, prompt: '5 + 7', answer: 12),
            const MathProblem(index: 1, level: 1, prompt: '2 + 9', answer: 11),
            const MathProblem(index: 2, level: 1, prompt: '9 + 7', answer: 16),
            const MathProblem(index: 3, level: 1, prompt: '4 + 8', answer: 12),
            const MathProblem(index: 4, level: 1, prompt: '6 + 5', answer: 11),
          ],
        ),
        (
          2024,
          7,
          5,
          [
            const MathProblem(index: 0, level: 7, prompt: '29 + 8 - 8', answer: 29),
            const MathProblem(index: 1, level: 7, prompt: '(3 × 2) + 14', answer: 20),
            const MathProblem(index: 2, level: 7, prompt: '15 + 9 - 3', answer: 21),
            const MathProblem(index: 3, level: 7, prompt: '(5 × 6) + 23', answer: 53),
            const MathProblem(index: 4, level: 7, prompt: '20 + 5 - 5', answer: 20),
          ],
        ),
        (
          2024,
          9,
          5,
          [
            const MathProblem(index: 0, level: 9, prompt: '(3 × 2) ÷ 3', answer: 2),
            const MathProblem(index: 1, level: 9, prompt: '(3 × 4) ÷ 3', answer: 4),
            const MathProblem(index: 2, level: 9, prompt: '(5 × 1) ÷ 5', answer: 1),
            const MathProblem(index: 3, level: 9, prompt: '(6 × 4) ÷ 2', answer: 12),
            const MathProblem(index: 4, level: 9, prompt: '(12 × 4) ÷ 3', answer: 16),
          ],
        ),
        (
          2024,
          10,
          5,
          [
            const MathProblem(index: 0, level: 10, prompt: '(8 × 34) - (18 × 6)', answer: 164),
            const MathProblem(index: 1, level: 10, prompt: '(28 × 5) - (9 × 11)', answer: 41),
            const MathProblem(index: 2, level: 10, prompt: '(26 × 5) - (8 × 15)', answer: 10),
            const MathProblem(index: 3, level: 10, prompt: '(9 × 41) - (26 × 9)', answer: 135),
            const MathProblem(index: 4, level: 10, prompt: '(8 × 48) - (20 × 9)', answer: 204),
          ],
        ),
      ];

      for (final (seed, level, count, expected) in cases) {
        final problems = generator.generateSessionProblems(seed: seed, level: level, count: count);
        for (var i = 0; i < expected.length; i++) {
          expect(problems[i].prompt, expected[i].prompt, reason: 'seed=$seed level=$level index=$i');
          expect(problems[i].answer, expected[i].answer, reason: 'seed=$seed level=$level index=$i');
        }
      }
    });
  });
}
