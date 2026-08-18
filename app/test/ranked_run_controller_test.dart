import 'package:brain_math/features/game/application/ranked_run_controller.dart';
import 'package:brain_math/features/game/data/ranked_session_repository.dart';
import 'package:brain_math/features/game/domain/ranked_models.dart';
import 'package:brain_math/features/game/domain/ranked_problem_generator.dart';
import 'package:brain_math/features/ink/domain/ink_models.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeClock {
  DateTime value = DateTime.utc(2026, 1, 1, 9);
  DateTime call() => value;
  void advance(Duration duration) => value = value.add(duration);
}

class _FakeSessionRepository implements RankedSessionRepository {
  _FakeSessionRepository({
    required this.envelope,
    this.createError,
    this.submitError,
  });

  final RankedSessionEnvelope envelope;
  final Object? createError;
  final Object? submitError;

  final List<List<RankedSubmissionAnswer>> submissions = <List<RankedSubmissionAnswer>>[];
  int createCalls = 0;

  @override
  Future<RankedSessionEnvelope> createRankedSession({required int level}) async {
    createCalls++;
    if (createError != null) throw createError!;
    return envelope;
  }

  @override
  Future<RankedSubmissionResult> submitRankedSession({
    required String sessionId,
    required List<RankedSubmissionAnswer> answers,
  }) async {
    submissions.add(answers);
    if (submitError != null) throw submitError!;
    return const RankedSubmissionResult(
      attemptId: 'attempt-1',
      brainScore: 1234,
      accuracyRate: 0.8,
      comboMax: 4,
      correctCount: 8,
    );
  }
}

RankedSessionEnvelope _envelope({int problemCount = 3, int level = 1, int seed = 42}) {
  return RankedSessionEnvelope(
    sessionId: 'session-1',
    seasonId: '2026_s1',
    seed: seed,
    level: level,
    levelBucket: 'level-$level',
    problemCount: problemCount,
    expiresAt: DateTime.utc(2026, 1, 1, 9, 5),
    balanceVersion: 'game_balance_v1',
  );
}

void main() {
  late _FakeClock clock;

  setUp(() => clock = _FakeClock());

  RankedRunController build(_FakeSessionRepository repository) {
    final controller = RankedRunController(
      sessionRepository: repository,
      clock: clock.call,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  test('시작하면 서버 시드로 문제를 만들고 플레이 상태가 된다', () async {
    final repository = _FakeSessionRepository(envelope: _envelope(problemCount: 3));
    final controller = build(repository);

    await controller.start(level: 1);

    expect(repository.createCalls, 1);
    expect(controller.phase, RankedPhase.playing);
    expect(controller.problemCount, 3);
    expect(controller.currentIndex, 0);
    expect(controller.currentProblem, isNotNull);

    // 서버와 같은 시드/레벨/문제 수로 만들어야 채점이 맞습니다.
    final expected = const RankedProblemGenerator()
        .generateSession(seed: 42, level: 1, count: 3);
    expect(controller.currentProblem!.prompt, expected.first.prompt);
  });

  test('세션 발급이 실패하면 이유를 문장으로 보여 준다', () async {
    final repository = _FakeSessionRepository(
      envelope: _envelope(),
      createError: Exception('boom'),
    );
    final controller = build(repository);

    await controller.start(level: 1);

    expect(controller.phase, RankedPhase.failed);
    expect(controller.errorMessage, isNotEmpty);
  });

  test('빈 답은 제출되지 않는다', () async {
    final repository = _FakeSessionRepository(envelope: _envelope());
    final controller = build(repository);
    await controller.start(level: 1);

    expect(await controller.submitCurrentProblem(), isFalse);
    expect(controller.answeredCount, 0);
  });

  test('마지막 문제까지 풀면 문제 수만큼 답을 모아 한 번에 제출한다', () async {
    final repository = _FakeSessionRepository(envelope: _envelope(problemCount: 3));
    final controller = build(repository);
    await controller.start(level: 1);

    for (var i = 0; i < 3; i++) {
      clock.advance(const Duration(milliseconds: 1500));
      controller.updateManualFallback('${i + 1}');
      expect(await controller.submitCurrentProblem(), isTrue);
    }

    expect(repository.submissions, hasLength(1));
    expect(repository.submissions.single, hasLength(3));
    expect(
      repository.submissions.single.map((answer) => answer.text).toList(),
      <String>['1', '2', '3'],
    );
    expect(repository.submissions.single.first.elapsedMs, 1500);
    expect(controller.phase, RankedPhase.done);
    expect(controller.result?.brainScore, 1234);
  });

  test('중간에 그만두면 남은 문제를 빈 답으로 채워 제출한다', () async {
    final repository = _FakeSessionRepository(envelope: _envelope(problemCount: 4));
    final controller = build(repository);
    await controller.start(level: 1);

    clock.advance(const Duration(seconds: 2));
    controller.updateManualFallback('7');
    await controller.submitCurrentProblem();

    await controller.giveUpAndSubmit();

    final sent = repository.submissions.single;
    expect(sent, hasLength(4));
    expect(sent.first.text, '7');
    expect(sent.skip(1).every((answer) => answer.text.isEmpty), isTrue);
    expect(controller.phase, RankedPhase.done);
  });

  test('제출이 실패하면 실패 상태가 된다', () async {
    final repository = _FakeSessionRepository(
      envelope: _envelope(problemCount: 1),
      submitError: Exception('network'),
    );
    final controller = build(repository);
    await controller.start(level: 1);

    controller.updateManualFallback('5');
    await controller.submitCurrentProblem();

    expect(controller.phase, RankedPhase.failed);
    expect(controller.errorMessage, isNotEmpty);
  });

  test('필기 정보가 답과 함께 실린다', () async {
    final repository = _FakeSessionRepository(envelope: _envelope(problemCount: 1));
    final controller = build(repository);
    await controller.start(level: 1);

    controller.updateInk(<InkStrokeData>[
      const InkStrokeData(
        points: <InkPointData>[
          InkPointData(x: 1, y: 2, t: 0),
          InkPointData(x: 3, y: 4, t: 10),
        ],
      ),
    ]);
    controller.updateRecognitionPreview(' 12 ');
    await controller.submitCurrentProblem();

    final answer = repository.submissions.single.single;
    expect(answer.text, '12');
    expect(answer.strokeCount, 1);
    expect(answer.pointCount, 2);
    expect(answer.inkHash, hasLength(8));
  });

  test('너무 빨리 눌러도 풀이 시간은 최소값으로 올라간다', () async {
    final repository = _FakeSessionRepository(envelope: _envelope(problemCount: 1));
    final controller = build(repository);
    await controller.start(level: 1);

    controller.updateManualFallback('1');
    await controller.submitCurrentProblem();

    expect(repository.submissions.single.single.elapsedMs, 250);
  });

  test('남은 세션 시간을 알려 준다', () async {
    final repository = _FakeSessionRepository(envelope: _envelope());
    final controller = build(repository);
    await controller.start(level: 1);

    expect(controller.timeLeft, const Duration(minutes: 5));
    clock.advance(const Duration(minutes: 6));
    expect(controller.timeLeft, Duration.zero);
  });
}
