import 'dart:convert';
import 'dart:io';

import 'package:brain_math/features/time_attack/domain/answer_normalizer.dart';
import 'package:brain_math/features/time_attack/domain/brain_score.dart';
import 'package:brain_math/features/time_attack/domain/game_mode.dart';
import 'package:brain_math/features/time_attack/domain/problem_generator.dart';
import 'package:flutter_test/flutter_test.dart';

/// 서버(functions/src/gameEngine.ts)가 만든 벡터와 클라이언트 엔진이 같은 결과를 내는지 확인합니다.
/// 여기서 실패하면 랭크 기록이 서버 재채점에서 틀리게 됩니다.
void main() {
  final golden =
      jsonDecode(File('../shared/engine_golden.json').readAsStringSync())
          as Map<String, dynamic>;

  GameMode modeOf(Object? id) => GameModeId.tryParse(id as String?)!;

  test('problem generator matches server vectors', () {
    const generator = ProblemGenerator();
    for (final group in golden['problems'] as List<dynamic>) {
      final map = group as Map<String, dynamic>;
      final mode = modeOf(map['mode']);
      final seed = map['seed'] as int;
      final items = (map['items'] as List<dynamic>).cast<String>();
      for (var index = 0; index < items.length; index++) {
        final problem =
            generator.generateProblem(seed: seed, mode: mode, index: index);
        expect('${problem.prompt} = ${problem.answer}', items[index],
            reason: '$mode seed=$seed index=$index');
      }
    }
  });

  test('answer normalizer matches server vectors', () {
    for (final item in golden['normalize'] as List<dynamic>) {
      final map = item as Map<String, dynamic>;
      expect(normalizeAnswer(map['input'] as String), map['output'],
          reason: 'input=${map['input']}');
    }
  });

  test('brain score matches server vectors', () {
    const calculator = BrainScoreCalculator();
    for (final item in golden['scores'] as List<dynamic>) {
      final map = item as Map<String, dynamic>;
      final attempts = (map['attempts'] as List<dynamic>)
          .map((raw) => raw as List<dynamic>)
          .map((pair) => ProblemAttemptResult(
              correct: pair[0] as bool, elapsedMs: pair[1] as int))
          .toList();
      final score =
          calculator.calculate(mode: modeOf(map['mode']), attempts: attempts);
      expect(score.brainScore, map['brainScore'],
          reason: '${map['mode']} ${map['attempts']}');
      expect(score.comboMax, map['comboMax']);
      expect(score.correctCount, map['correctCount']);
    }
  });
}
