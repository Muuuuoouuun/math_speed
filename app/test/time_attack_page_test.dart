import 'package:brain_math/features/time_attack/application/time_attack_session_controller.dart';
import 'package:brain_math/features/time_attack/domain/game_mode.dart';
import 'package:brain_math/features/time_attack/domain/ranked_models.dart';
import 'package:brain_math/features/time_attack/presentation/time_attack_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gateway implements RankedGateway {
  final List<RankedSubmissionAnswer> submitted = [];

  @override
  Future<RankedSessionEnvelope> createRankedSession(
          {required GameMode mode}) async =>
      RankedSessionEnvelope(
        sessionId: 'time-attack-session',
        seasonId: '2026_s1',
        seed: 42,
        mode: mode,
        levelBucket: 'mode-${mode.id}',
        expiresAt: DateTime(2026, 10, 29, 10),
        balanceVersion: 'game_balance_v2',
      );

  @override
  Future<RankedSubmissionResult> submitRankedSession({
    required String sessionId,
    required List<RankedSubmissionAnswer> answers,
  }) async {
    submitted.addAll(answers);
    return RankedSubmissionResult(
      attemptId: 'time-attack-attempt',
      brainScore: 300,
      accuracyRate: 1,
      comboMax: answers.length,
      correctCount: answers.length,
      attemptCount: answers.length,
      seasonBest: 300,
      isNewBest: true,
      flagged: false,
    );
  }
}

void main() {
  testWidgets(
      'a small screen supports mode selection, answering and official results',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var now = DateTime(2026, 10, 29, 9);
    final gateway = _Gateway();
    final controller =
        TimeAttackSessionController(clock: () => now, rankedGateway: gateway);

    await tester.pumpWidget(MaterialApp(
        home: TimeAttackPage(controller: controller, showLeaderboard: false)));
    await tester.tap(find.text('사칙연산'));
    await tester.tap(find.byKey(const Key('time-attack-start')));
    await tester.pump();
    await tester.pump();
    expect(controller.gameMode, GameMode.fourOperations);
    expect(controller.isRunning, isTrue);

    final input = find.byKey(const Key('time-attack-answer'));
    await tester.ensureVisible(input);
    await tester.enterText(input, '${controller.currentProblem!.answer}');
    await tester.pump();
    now = now.add(const Duration(seconds: 2));
    final submit = find.byKey(const Key('time-attack-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(controller.correctCount, 1);
    expect(find.textContaining('정답!'), findsOneWidget);

    now = now.add(Duration(milliseconds: controller.timeLeftMs + 1));
    controller.tick();
    await tester.pump();
    await tester.pump();
    expect(find.text('시즌 최고 기록!'), findsOneWidget);
    expect(gateway.submitted, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('offline entry starts practice without creating a ranked session',
      (tester) async {
    final controller = TimeAttackSessionController();
    await tester.pumpWidget(MaterialApp(
        home: TimeAttackPage(controller: controller, online: false)));
    expect(find.textContaining('오프라인 연습'), findsOneWidget);
    await tester.tap(find.byKey(const Key('time-attack-start')));
    await tester.pump();
    expect(controller.isRunning, isTrue);
    expect(controller.isRanked, isFalse);
    expect(controller.rankedSession, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
