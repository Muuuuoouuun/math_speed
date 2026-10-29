import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AppEnvironment {
  const AppEnvironment({
    required this.firebaseReady,
    this.firebaseError,
  });

  final bool firebaseReady;
  final Object? firebaseError;
}

/// 초기화가 끝나기를 기다리는 최대 시간.
///
/// 네트워크가 막힌 곳에서는 Firebase 초기화가 끝나지 않고 멈춰 있을 수 있는데,
/// 그동안 화면이 비어 있으면 앱이 죽은 것처럼 보입니다. 시간이 지나면 오프라인
/// 모드로 넘어가 손글씨 연습은 그대로 할 수 있게 합니다.
const Duration _bootstrapTimeout = Duration(seconds: 8);

Future<AppEnvironment> bootstrapEnvironment() async {
  try {
    await Firebase.initializeApp().timeout(_bootstrapTimeout);
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously().timeout(_bootstrapTimeout);
    }

    return const AppEnvironment(firebaseReady: true);
  } catch (error) {
    return AppEnvironment(
      firebaseReady: false,
      firebaseError: error,
    );
  }
}
