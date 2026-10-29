import 'package:brain_math/core/theme/app_theme.dart';
import 'package:brain_math/features/profile/domain/player_profile.dart';
import 'package:brain_math/features/profile/presentation/profile_setup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const List<Size> _screens = <Size>[
  Size(320, 568),
  Size(430, 932),
  Size(834, 1194),
];

Widget _app({bool isBusy = false, List<ProfileDraft>? submitted}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: ProfileSetupPage(
      initialProfile: null,
      isBusy: isBusy,
      onSubmit: (draft) async => submitted?.add(draft),
    ),
  );
}

void main() {
  for (final size in _screens) {
    testWidgets('${size.width.toInt()}x${size.height.toInt()} 프로필 화면이 넘치지 않는다',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_app());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('학습 프로필'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets('닉네임이 비어 있으면 저장하지 않고 안내한다', (tester) async {
    tester.view.physicalSize = const Size(834, 1194);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final submitted = <ProfileDraft>[];
    await tester.pumpWidget(_app(submitted: submitted));
    await tester.pump();

    await tester.tap(find.text('연필 잡고 시작하기'));
    await tester.pump();

    expect(submitted, isEmpty);
    expect(find.text('이름이나 닉네임을 입력해 주세요.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('닉네임을 적으면 입력한 값이 그대로 전달된다', (tester) async {
    tester.view.physicalSize = const Size(834, 1194);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final submitted = <ProfileDraft>[];
    await tester.pumpWidget(_app(submitted: submitted));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '연필이');
    await tester.tap(find.text('연필 잡고 시작하기'));
    await tester.pump();

    expect(submitted, hasLength(1));
    expect(submitted.single.displayName, '연필이');
    expect(submitted.single.grade, 4);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
