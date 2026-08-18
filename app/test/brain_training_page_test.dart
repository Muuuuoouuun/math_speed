import 'package:brain_math/core/bootstrap/app_environment.dart';
import 'package:brain_math/core/theme/app_theme.dart';
import 'package:brain_math/features/game/presentation/brain_training_page.dart';
import 'package:brain_math/features/profile/domain/player_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 화면 크기를 바꿔 가며 확인합니다. RenderFlex 오버플로가 나면 테스트가
/// 곧바로 실패하므로, 이 목록이 레이아웃 회귀를 막아 줍니다.
const List<Size> _screens = <Size>[
  Size(320, 568), // 작은 폰
  Size(430, 932), // 큰 폰
  Size(834, 1194), // 태블릿
];

Widget _app({bool online = false, PlayerProfile? profile}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: BrainTrainingPage(
      environment: AppEnvironment(firebaseReady: online),
      profile: profile,
    ),
  );
}

const PlayerProfile _profile = PlayerProfile(
  uid: 'uid-1',
  displayName: '연필이',
  schoolId: 'seoul-junior',
  regionCode: 'KR-11',
  grade: 4,
);

Future<void> _setScreen(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// 마스코트가 계속 흔들리기 때문에 pumpAndSettle은 영영 끝나지 않습니다.
/// 대신 필요한 만큼만 프레임을 진행시킵니다.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// 목록을 위로 밀어 [finder]가 만들어질 때까지 찾습니다.
/// (ListView는 보이는 항목만 만들기 때문에 작은 화면에서는 필수입니다.)
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 10 && finder.evaluate().isEmpty; i++) {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.dragFrom(Offset(size.width / 2, 120), const Offset(0, -240));
    await tester.pump(const Duration(milliseconds: 400));
  }
  expect(finder, findsOneWidget);
}

/// 목록을 맨 위로 되돌립니다.
Future<void> _scrollToTop(WidgetTester tester) async {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  for (var i = 0; i < 10; i++) {
    await tester.dragFrom(Offset(size.width / 2, 120), const Offset(0, 240));
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.pump(const Duration(milliseconds: 400));
}

/// 화면을 비워서 페이지가 dispose되게 합니다. 남아 있는 타이머 정리에 필요합니다.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _startRound(WidgetTester tester) async {
  await _reveal(tester, find.textContaining('시작하기'));
  await tester.tap(find.textContaining('시작하기'));
  await tester.pump();

  expect(find.text('연필 준비!'), findsOneWidget);
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 700));
  }
  await _settle(tester);
}

void main() {
  for (final size in _screens) {
    testWidgets('${size.width.toInt()}x${size.height.toInt()} 시작 화면이 넘치지 않는다',
        (tester) async {
      await _setScreen(tester, size);
      await tester.pumpWidget(_app());
      await _settle(tester);

      expect(find.text('연필 계산'), findsOneWidget);

      await _reveal(tester, find.text('난이도를 골라요'));
      expect(find.text('단순계산'), findsOneWidget);

      await _reveal(tester, find.textContaining('시작하기'));

      await _unmount(tester);
    });
  }

  testWidgets('난이도를 고르면 시작 버튼 문구가 따라 바뀐다', (tester) async {
    await _setScreen(tester, const Size(430, 932));
    await tester.pumpWidget(_app());
    await _settle(tester);

    await _reveal(tester, find.textContaining('시작하기'));
    expect(find.text('단순계산 시작하기'), findsOneWidget);

    await _scrollToTop(tester);
    await _reveal(tester, find.text('세자리수'));
    await tester.tap(find.text('세자리수'));
    await _settle(tester);

    await _reveal(tester, find.textContaining('시작하기'));
    expect(find.text('세자리수 시작하기'), findsOneWidget);

    await _unmount(tester);
  });

  for (final size in _screens) {
    testWidgets('${size.width.toInt()}x${size.height.toInt()} 카운트다운 뒤 플레이 화면이 뜬다',
        (tester) async {
      await _setScreen(tester, size);
      await tester.pumpWidget(_app());
      await _settle(tester);

      await _startRound(tester);

      expect(find.text('연필 준비!'), findsNothing);
      expect(find.text('남은 시간'), findsOneWidget);
      expect(find.text('그만두기'), findsOneWidget);

      await _reveal(tester, find.text('정답 확인'));
      expect(find.text('연습장'), findsOneWidget);

      await _unmount(tester);
    });
  }

  testWidgets('그만두기를 누르면 시작 화면으로 돌아간다', (tester) async {
    await _setScreen(tester, const Size(430, 932));
    await tester.pumpWidget(_app());
    await _settle(tester);

    await _startRound(tester);
    await tester.tap(find.text('그만두기'));
    await _settle(tester);

    await _reveal(tester, find.text('난이도를 골라요'));

    await _unmount(tester);
  });

  testWidgets('오프라인이면 랭크전이 잠기고 이유를 알려 준다', (tester) async {
    await _setScreen(tester, const Size(430, 932));
    await tester.pumpWidget(_app());
    await _settle(tester);

    await _reveal(tester, find.text('랭크전'));
    expect(find.text('지금은 오프라인이라 랭크전을 열 수 없어요.'), findsOneWidget);
    expect(find.text('랭크전 들어가기'), findsNothing);

    await _unmount(tester);
  });

  testWidgets('프로필이 있으면 랭크전에 들어갈 수 있다', (tester) async {
    await _setScreen(tester, const Size(430, 932));
    await tester.pumpWidget(_app(online: true, profile: _profile));
    await _settle(tester);

    await _reveal(tester, find.text('랭크전 들어가기'));
    expect(find.text('난이도 1'), findsOneWidget);

    // 난이도를 바꾸면 표시가 따라옵니다.
    await tester.ensureVisible(find.text('7'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('7'));
    await _settle(tester);
    expect(find.text('난이도 7'), findsOneWidget);

    await _unmount(tester);
  });
}
