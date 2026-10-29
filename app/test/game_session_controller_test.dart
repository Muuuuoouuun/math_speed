import 'package:brain_math/features/game/application/game_session_controller.dart';
import 'package:brain_math/features/game/domain/game_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameSessionController 진행 단계', () {
    test('처음에는 시작 화면이고 게이지가 채워져 있다', () {
      final controller = GameSessionController();
      addTearDown(controller.dispose);

      expect(controller.phase, RoundPhase.ready);
      expect(controller.isReady, isTrue);
      expect(controller.isRunning, isFalse);
      expect(controller.timeLeftMs, controller.gameModeConfig.initialTimeMs);
      expect(controller.timeRatio, greaterThan(0));
    });

    test('시작 화면에서 난이도를 바꿔도 판이 시작되지 않는다', () {
      final controller = GameSessionController();
      addTearDown(controller.dispose);

      controller.setGameMode(GameMode.tripleDigit);

      expect(controller.phase, RoundPhase.ready);
      expect(controller.gameMode, GameMode.tripleDigit);
      expect(
        controller.timeLeftMs,
        GameModeConfig.fromMode(GameMode.tripleDigit).initialTimeMs,
      );
    });

    test('판을 시작하면 문제가 나오고 되돌아가면 초기화된다', () {
      final controller = GameSessionController();
      addTearDown(controller.dispose);

      controller.startRound(mode: GameMode.simpleCalculation);
      expect(controller.phase, RoundPhase.playing);
      expect(controller.currentProblem, isNotNull);

      controller.returnToReady();
      expect(controller.phase, RoundPhase.ready);
      expect(controller.currentProblem, isNull);
      expect(controller.attemptCount, 0);
      expect(controller.currentCombo, 0);
    });
  });

  group('정답 처리', () {
    test('정답이면 콤보가 오르고 보너스 시간이 최대치를 넘지 않는다', () {
      final controller = GameSessionController();
      addTearDown(controller.dispose);

      controller.startRound(mode: GameMode.simpleCalculation, seed: 7);
      final answer = controller.currentProblem!.answer;
      controller.updateManualFallback('$answer');

      expect(controller.submitCurrentProblem(), isTrue);
      expect(controller.lastAttemptCorrect, isTrue);
      expect(controller.currentCombo, 1);
      expect(controller.timeLeftMs, lessThanOrEqualTo(controller.gameModeConfig.maxTimeMs));
      expect(controller.totalBonusMs, greaterThan(0));
    });

    test('오답이면 콤보가 끊기고 정답이 기록된다', () {
      final controller = GameSessionController();
      addTearDown(controller.dispose);

      controller.startRound(mode: GameMode.simpleCalculation, seed: 11);
      final expected = controller.currentProblem!.answer;
      controller.updateManualFallback('${expected + 1}');

      expect(controller.submitCurrentProblem(), isTrue);
      expect(controller.lastAttemptCorrect, isFalse);
      expect(controller.currentCombo, 0);
      expect(controller.lastExpectedAnswer, expected);
    });

    test('입력이 비어 있으면 제출되지 않는다', () {
      final controller = GameSessionController();
      addTearDown(controller.dispose);

      controller.startRound(mode: GameMode.simpleCalculation);

      expect(controller.submitCurrentProblem(), isFalse);
      expect(controller.attemptCount, 0);
    });
  });

  test('clearInk은 손글씨만 지우고 문제는 유지한다', () {
    final controller = GameSessionController();
    addTearDown(controller.dispose);

    controller.startRound(mode: GameMode.fourOperations);
    final problem = controller.currentProblem;
    controller.updateRecognitionPreview('42');
    final revisionBefore = controller.clearRevision;

    controller.clearInk();

    expect(controller.recognizedText, isEmpty);
    expect(controller.clearRevision, revisionBefore + 1);
    expect(controller.currentProblem, same(problem));
  });

  test('인식기가 흘린 기호가 붙어도 정답으로 본다', () {
    final controller = GameSessionController();
    addTearDown(controller.dispose);

    controller.startRound(mode: GameMode.simpleCalculation, seed: 3);
    final answer = controller.currentProblem!.answer;
    controller.updateRecognitionPreview('$answer.');

    expect(controller.submitCurrentProblem(), isTrue);
    expect(controller.lastAttemptCorrect, isTrue);
  });

  test('숫자가 하나도 없는 입력은 제출되지 않는다', () {
    final controller = GameSessionController();
    addTearDown(controller.dispose);

    controller.startRound(mode: GameMode.simpleCalculation);
    controller.updateManualFallback('???');

    expect(controller.submitCurrentProblem(), isFalse);
    expect(controller.attemptCount, 0);
  });
}
