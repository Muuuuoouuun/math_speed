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
            const MathProblem(index: 0, level: 1, prompt: '5 + 5', answer: 10),
            const MathProblem(index: 1, level: 1, prompt: '2 + 3', answer: 5),
            const MathProblem(index: 2, level: 1, prompt: '9 + 1', answer: 10),
            const MathProblem(index: 3, level: 1, prompt: '4 + 1', answer: 5),
            const MathProblem(index: 4, level: 1, prompt: '6 + 5', answer: 11),
          ],
        ),
        (
          2024,
          7,
          5,
          [
            const MathProblem(index: 0, level: 7, prompt: '7 + 8 - 8', answer: 7),
            const MathProblem(index: 1, level: 7, prompt: '(3 × 2) + 11', answer: 17),
            const MathProblem(index: 2, level: 7, prompt: '17 + 9 - 3', answer: 23),
            const MathProblem(index: 3, level: 7, prompt: '(5 × 6) + 9', answer: 39),
            const MathProblem(index: 4, level: 7, prompt: '28 + 5 - 5', answer: 28),
          ],
        ),
        (
          2024,
          9,
          5,
          [
            const MathProblem(index: 0, level: 9, prompt: '(8 × 6) ÷ 3', answer: 16),
            const MathProblem(index: 1, level: 9, prompt: '(4 × 6) ÷ 3', answer: 8),
            const MathProblem(index: 2, level: 9, prompt: '(6 × 15) ÷ 5', answer: 18),
            const MathProblem(index: 3, level: 9, prompt: '(7 × 8) ÷ 2', answer: 28),
            const MathProblem(index: 4, level: 9, prompt: '(5 × 12) ÷ 3', answer: 20),
          ],
        ),
        (
          2024,
          10,
          5,
          [
            const MathProblem(index: 0, level: 10, prompt: '(10 × 4) - (3 × 8)', answer: 16),
            const MathProblem(index: 1, level: 10, prompt: '(12 × 5) - (4 × 9)', answer: 24),
            const MathProblem(index: 2, level: 10, prompt: '(12 × 4) - (2 × 13)', answer: 22),
            const MathProblem(index: 3, level: 10, prompt: '(5 × 24) - (17 × 6)', answer: 18),
            const MathProblem(index: 4, level: 10, prompt: '(7 × 20) - (12 × 9)', answer: 32),
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

    test('difficulty ramps up within a session: later problems use visibly larger numbers', () {
      // A generic, level-agnostic proxy (largest number appearing anywhere in the prompt),
      // averaged over a quarter of a long session at a time, to avoid being sensitive to any
      // single draw. Unlike practice mode, a ranked session has a fixed problem count and every
      // level's ranges are ramped, so this signal is clean without needing to filter branches.
      int maxOperand(String prompt) {
        final numbers = RegExp(r'\d+').allMatches(prompt).map((m) => int.parse(m.group(0)!));
        return numbers.reduce((a, b) => a > b ? a : b);
      }

      for (final level in _allLevels) {
        for (final seed in _seeds) {
          const count = 300;
          final problems = generator.generateSessionProblems(seed: seed, level: level, count: count);
          final firstQuarter = problems.take(count ~/ 4).map((p) => maxOperand(p.prompt));
          final lastQuarter = problems.skip(count - (count ~/ 4)).map((p) => maxOperand(p.prompt));
          double average(Iterable<int> values) => values.reduce((a, b) => a + b) / values.length;
          expect(
            average(lastQuarter),
            greaterThan(average(firstQuarter)),
            reason: 'level=$level seed=$seed: expected the session\'s back quarter to skew harder than its front quarter',
          );
        }
      }
    });
  });
}
