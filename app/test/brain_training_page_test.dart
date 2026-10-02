import 'package:brain_math/core/bootstrap/app_environment.dart';
import 'package:brain_math/features/game/presentation/brain_training_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offline practice round can be played with manual input', (tester) async {
    // 세로로 긴 휴대폰 화면 전체를 한 번에 그려 스크롤 없이 버튼을 찾습니다.
    tester.view.physicalSize = const Size(1170, 5000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: BrainTrainingPage(environment: AppEnvironment(firebaseReady: false)),
      ),
    );

    expect(find.text('연필 계산'), findsOneWidget);
    expect(find.text('offline'), findsOneWidget);
    // 오프라인에서는 랭크 전환과 랭킹 패널이 보이지 않아야 합니다.
    expect(find.text('랭크'), findsNothing);
    expect(find.text('시즌 랭킹'), findsNothing);

    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('정답 확인'));
    await tester.pump();

    expect(find.text('다음 문제로 이어가요'), findsOneWidget);

    // 주기 타이머를 정리하기 위해 페이지를 내립니다.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
