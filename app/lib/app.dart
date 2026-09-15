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
      home: AppShell(environment: environment),
    );
  }
}
