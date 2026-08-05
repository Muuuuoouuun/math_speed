import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'core/bootstrap/app_environment.dart';
import 'core/theme/app_theme.dart';

class BrainMathApp extends StatelessWidget {
  const BrainMathApp({
    required this.environment,
    super.key,
  });

  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '연필 계산',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // 기기 글꼴 크기를 크게 키워 둔 경우에도 레이아웃이 무너지지 않도록
      // 배율에 상한을 둡니다.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.25),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: AppShell(environment: environment),
    );
  }
}
