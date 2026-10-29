import 'dart:async';

import 'package:brain_math/core/theme/app_theme.dart';
import 'package:brain_math/features/game/data/leaderboard_repository.dart';
import 'package:brain_math/features/game/data/ranked_session_repository.dart';
import 'package:brain_math/features/game/domain/leaderboard_models.dart';
import 'package:brain_math/features/game/domain/ranked_models.dart';
import 'package:brain_math/features/game/presentation/ranked_run_page.dart';
import 'package:brain_math/features/ink/application/digital_ink_service.dart';
import 'package:brain_math/features/ink/domain/ink_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const List<Size> _screens = <Size>[
  Size(320, 568),
  Size(430, 932),
  Size(834, 1194),
];

class _FakeInkService implements DigitalInkService {
  @override
  Future<void> ensureModelDownloaded() async {}

  @override
  Future<RecognitionPreview?> recognize(
    List<InkStrokeData> strokes, {
    double writingAreaWidth = 320,
    double writingAreaHeight = 180,
  }) async =>
      null;

  @override
  Future<void> dispose() async {}
}

class _FakeLeaderboardRepository implements LeaderboardRepository {
  _FakeLeaderboardRepository({this.entries = const <LeaderboardEntry>[]});

  final List<LeaderboardEntry> entries;

  @override
  Future<List<LeaderboardEntry>> loadTopEntries({required String scope, int limit = 5}) async {
    return entries;
  }
}

class _FakeSessionRepository implements RankedSessionRepository {
  _FakeSessionRepository({
    this.problemCount = 3,
    this.createError,
    this.gate,
  });

  final int problemCount;
  final Object? createError;
  final Completer<void>? gate;

  @override
  Future<RankedSessionEnvelope> createRankedSession({required int level}) async {
    if (gate != null) await gate!.future;
    if (createError != null) throw createError!;
    return RankedSessionEnvelope(
      sessionId: 'session-1',
      seasonId: '2026_s1',
      seed: 42,
      level: level,
      levelBucket: 'level-$level',
      problemCount: problemCount,
      // 실제 시계를 쓰므로 넉넉히 남겨 둡니다. 12초 아래로 떨어지면 자동 제출됩니다.
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      balanceVersion: 'game_balance_v1',
    );
  }

  @override
  Future<RankedSubmissionResult> submitRankedSession({
    required String sessionId,
    required List<RankedSubmissionAnswer> answers,
  }) async {
    return const RankedSubmissionResult(
      attemptId: 'attempt-1',
      brainScore: 1234,
      accuracyRate: 0.75,
      comboMax: 3,
      correctCount: 6,
    );
  }
}

Widget _page({
  required RankedSessionRepository session,
  LeaderboardRepository? leaderboard,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: RankedRunPage(
      level: 1,
      sessionRepository: session,
      leaderboardRepository: leaderboard ?? _FakeLeaderboardRepository(),
      digitalInkService: _FakeInkService(),
    ),
  );
}

Future<void> _setScreen(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// 목록을 위로 밀어 [finder]가 만들어질 때까지 찾습니다.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 10 && finder.evaluate().isEmpty; i++) {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.dragFrom(Offset(size.width / 2, 100), const Offset(0, -240));
    await tester.pump(const Duration(milliseconds: 400));
  }
  expect(finder, findsOneWidget);
}

/// 목록을 맨 위로 되돌립니다. 작은 화면에서는 스크롤 위치에 따라 위쪽 항목이
/// 아예 만들어지지 않기 때문에 필요합니다.
Future<void> _toTop(WidgetTester tester) async {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  for (var i = 0; i < 10; i++) {
    await tester.dragFrom(Offset(size.width / 2, 100), const Offset(0, 240));
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('세션을 받아오는 동안 안내를 보여 준다', (tester) async {
    await _setScreen(tester, const Size(430, 932));
    final gate = Completer<void>();
    await tester.pumpWidget(_page(session: _FakeSessionRepository(gate: gate)));
    await tester.pump();

    expect(find.text('문제를 받아오는 중'), findsOneWidget);

    gate.complete();
    await _settle(tester);
    expect(find.text('문제를 받아오는 중'), findsNothing);

    await _unmount(tester);
  });

  for (final size in _screens) {
    testWidgets('${size.width.toInt()}x${size.height.toInt()} 랭크전 화면이 넘치지 않는다',
        (tester) async {
      await _setScreen(tester, size);
      await tester.pumpWidget(_page(session: _FakeSessionRepository()));
      await _settle(tester);

      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('랭크전 레벨 1'), findsOneWidget);

      await _reveal(tester, find.text('다음 문제'));

      // 한 문제 풀어 채점 스탬프가 뜬 상태에서도 넘치지 않아야 합니다.
      await _reveal(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), '1');
      await tester.pump();
      await _reveal(tester, find.text('다음 문제'));
      await tester.tap(find.text('다음 문제'));
      await _settle(tester);
      await _toTop(tester);

      expect(find.text('2 / 3'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && (widget.data == '잘했어요!' || widget.data == '아쉬워요'),
        ),
        findsOneWidget,
      );

      await _unmount(tester);
    });
  }

  testWidgets('문제를 다 풀면 서버 점수와 순위를 보여 준다', (tester) async {
    await _setScreen(tester, const Size(430, 932));
    await tester.pumpWidget(
      _page(
        session: _FakeSessionRepository(problemCount: 2),
        leaderboard: _FakeLeaderboardRepository(
          entries: const <LeaderboardEntry>[
            LeaderboardEntry(rank: 1, entityId: 'seoul-junior', score: 980.4, eligibleUsers: 12),
            LeaderboardEntry(rank: 2, entityId: 'han-river', score: 870.1, eligibleUsers: 9),
          ],
        ),
      ),
    );
    await _settle(tester);

    for (var i = 0; i < 2; i++) {
      await _reveal(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), '${i + 1}');
      await tester.pump();
      await _reveal(tester, find.byWidgetPredicate(
        (widget) => widget is Text && (widget.data == '다음 문제' || widget.data == '제출하기'),
      ));
      await tester.tap(find.byWidgetPredicate(
        (widget) => widget is Text && (widget.data == '다음 문제' || widget.data == '제출하기'),
      ));
      await _settle(tester);
    }

    expect(find.text('서버에 저장된 점수'), findsOneWidget);
    expect(find.text('1234'), findsOneWidget);

    await _reveal(tester, find.text('서울 두뇌 초등학교'));
    expect(find.text('980'), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('세션을 못 받으면 이유와 다시 시도를 보여 준다', (tester) async {
    await _setScreen(tester, const Size(430, 932));
    await tester.pumpWidget(
      _page(session: _FakeSessionRepository(createError: Exception('nope'))),
    );
    await _settle(tester);

    expect(find.text('기록하지 못했어요'), findsOneWidget);
    expect(find.text('다시 시도하기'), findsOneWidget);
    expect(find.text('연습으로 돌아가기'), findsOneWidget);

    await _unmount(tester);
  });
}
