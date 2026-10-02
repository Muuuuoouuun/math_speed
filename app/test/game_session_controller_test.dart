import 'dart:async';

import 'package:brain_math/features/game/application/game_session_controller.dart';
import 'package:brain_math/features/game/domain/game_mode.dart';
import 'package:brain_math/features/game/domain/problem_generator.dart';
import 'package:brain_math/features/game/domain/ranked_models.dart';
import 'package:brain_math/features/ink/domain/ink_models.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeClock {
  DateTime now = DateTime(2026, 10, 2, 9);

  void advance(int ms) => now = now.add(Duration(milliseconds: ms));
}

class _FakeGateway implements RankedGateway {
  _FakeGateway({this.seed = 4242});

  final int seed;
  Completer<RankedSessionEnvelope>? pendingCreate;
  Object? submitError;
  final List<List<RankedSubmissionAnswer>> submissions = <List<RankedSubmissionAnswer>>[];

  @override
  Future<RankedSessionEnvelope> createRankedSession({required GameMode mode}) {
    final envelope = RankedSessionEnvelope(
      sessionId: 'session-${mode.id}',
      seasonId: '2026_s1',
      seed: seed,
      mode: mode,
      levelBucket: mode.id,
      expiresAt: DateTime(2026, 10, 2, 10),
      balanceVersion: 'game_balance_v2',
    );
    final pending = pendingCreate;
    if (pending != null) {
      return pending.future;
    }
    return Future.value(envelope);
  }

  @override
  Future<RankedSubmissionResult> submitRankedSession({
    required String sessionId,
    required List<RankedSubmissionAnswer> answers,
  }) async {
    submissions.add(answers);
    final error = submitError;
    if (error != null) throw error;
    return RankedSubmissionResult(
      attemptId: 'attempt-1',
      brainScore: 321,
      accuracyRate: 1,
      comboMax: answers.length,
      correctCount: answers.length,
      attemptCount: answers.length,
      seasonBest: 321,
      isNewBest: true,
      flagged: false,
    );
  }
}

void main() {
  late _FakeClock clock;

  setUp(() {
    clock = _FakeClock();
  });

  void answerCorrectly(GameSessionController controller, {int thinkMs = 1200}) {
    clock.advance(thinkMs);
    controller.updateManualFallback('${controller.currentProblem!.answer}');
    expect(controller.submitCurrentProblem(), isTrue);
  }

  void runOutClock(GameSessionController controller) {
    clock.advance(controller.timeLeftMs + 1);
    controller.tick();
  }

  test('correct answers restore time and build a combo', () {
    final controller = GameSessionController(clock: () => clock.now);
    addTearDown(controller.dispose);
    controller.startRound(mode: GameMode.fourOperations, seed: 7);
    final config = GameModeConfig.fromMode(GameMode.fourOperations);

    clock.advance(3000);
    controller.tick();
    answerCorrectly(controller, thinkMs: 0);

    expect(controller.timeLeftMs, config.initialTimeMs - 3000 + config.bonusTimeMs);
    expect(controller.currentCombo, 1);
    expect(controller.records.single.elapsedMs, 3000);
    expect(controller.records.single.correct, isTrue);
  });

  test('handwriting recognition wins over manual input and is normalized', () {
    final controller = GameSessionController(clock: () => clock.now);
    addTearDown(controller.dispose);
    controller.startRound(mode: GameMode.simpleCalculation, seed: 1);
    final answer = controller.currentProblem!.answer;

    controller.updateManualFallback('999');
    controller.updateRecognitionPreview(' ${'$answer'.replaceAll('1', 'l')} ');
    expect(controller.pendingAnswer, '$answer');
    expect(controller.submitCurrentProblem(), isTrue);
    expect(controller.lastAttemptCorrect, isTrue);
  });

  test('empty input is not submitted and wrong answers reset the combo', () {
    final controller = GameSessionController(clock: () => clock.now);
    addTearDown(controller.dispose);
    controller.startRound(seed: 3);

    expect(controller.submitCurrentProblem(), isFalse);
    answerCorrectly(controller);
    controller.updateManualFallback('-1');
    expect(controller.submitCurrentProblem(), isTrue);
    expect(controller.currentCombo, 0);
    expect(controller.lastExpectedAnswer, isNotNull);
  });

  test('clearInk wipes the current ink without skipping the problem', () {
    final controller = GameSessionController(clock: () => clock.now);
    addTearDown(controller.dispose);
    controller.startRound(seed: 3);
    final problem = controller.currentProblem;
    final revision = controller.clearRevision;

    controller.updateInkMetrics(const InkMetrics(strokeCount: 2, pointCount: 30, inkHash: 'abc'));
    controller.updateRecognitionPreview('12');
    controller.clearInk();

    expect(controller.currentProblem, same(problem));
    expect(controller.recognizedText, isEmpty);
    expect(controller.currentInkMetrics.strokeCount, 0);
    expect(controller.clearRevision, revision + 1);
  });

  test('ranked round uses the server seed and submits every answer when time runs out', () async {
    final gateway = _FakeGateway(seed: 777);
    final controller = GameSessionController(clock: () => clock.now, rankedGateway: gateway);
    addTearDown(controller.dispose);

    await controller.startRankedRound(mode: GameMode.doubleDigit);
    expect(controller.isRanked, isTrue);
    expect(controller.rankedStatus, RankedRoundStatus.playing);
    expect(
      controller.currentProblem!.prompt,
      const ProblemGenerator().generateProblem(seed: 777, mode: GameMode.doubleDigit, index: 0).prompt,
    );

    controller.updateInkMetrics(const InkMetrics(strokeCount: 3, pointCount: 40, inkHash: 'feed'));
    answerCorrectly(controller);
    answerCorrectly(controller);
    runOutClock(controller);
    await Future<void>.delayed(Duration.zero);

    expect(controller.isGameOver, isTrue);
    expect(controller.rankedStatus, RankedRoundStatus.submitted);
    expect(controller.rankedResult!.brainScore, 321);
    final submitted = gateway.submissions.single;
    expect(submitted, hasLength(2));
    expect(submitted.first.strokeCount, 3);
    expect(submitted.first.inkHash, 'feed');
    expect(submitted.first.elapsedMs, 1200);
  });

  test('failed ranked submission can be retried with the same answers', () async {
    final gateway = _FakeGateway()..submitError = StateError('offline');
    final controller = GameSessionController(clock: () => clock.now, rankedGateway: gateway);
    addTearDown(controller.dispose);

    await controller.startRankedRound();
    answerCorrectly(controller);
    runOutClock(controller);
    await Future<void>.delayed(Duration.zero);
    expect(controller.rankedStatus, RankedRoundStatus.failed);
    expect(controller.rankedError, isNotEmpty);

    gateway.submitError = null;
    await controller.retryRankedSubmission();
    expect(controller.rankedStatus, RankedRoundStatus.submitted);
    expect(gateway.submissions, hasLength(2));
    expect(gateway.submissions.last, hasLength(1));
  });

  test('switching back to practice ignores a late ranked session response', () async {
    final gateway = _FakeGateway()..pendingCreate = Completer<RankedSessionEnvelope>();
    final controller = GameSessionController(clock: () => clock.now, rankedGateway: gateway);
    addTearDown(controller.dispose);

    final pending = controller.startRankedRound(mode: GameMode.tripleDigit);
    expect(controller.rankedStatus, RankedRoundStatus.preparing);
    expect(controller.isRunning, isFalse);

    controller.setSessionMode(SessionMode.practice);
    gateway.pendingCreate!.complete(
      RankedSessionEnvelope(
        sessionId: 'late',
        seasonId: '2026_s1',
        seed: 1,
        mode: GameMode.tripleDigit,
        levelBucket: 'tripleDigit',
        expiresAt: DateTime(2026, 10, 2, 10),
        balanceVersion: 'game_balance_v2',
      ),
    );
    await pending;

    expect(controller.isRanked, isFalse);
    expect(controller.rankedSession, isNull);
    expect(controller.isRunning, isTrue);
  });

  test('ranked play is unavailable without a gateway', () async {
    final controller = GameSessionController(clock: () => clock.now);
    addTearDown(controller.dispose);
    controller.startRound();
    await controller.startRankedRound();
    expect(controller.canPlayRanked, isFalse);
    expect(controller.isRanked, isFalse);
  });
}
