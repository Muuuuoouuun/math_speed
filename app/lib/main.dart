import 'package:flutter/material.dart';

import 'app.dart';
import 'core/bootstrap/app_environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = await bootstrapEnvironment();
  runApp(BrainMathApp(environment: environment));
}
