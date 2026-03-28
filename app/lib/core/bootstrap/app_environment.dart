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

Future<AppEnvironment> bootstrapEnvironment() async {
  try {
    await Firebase.initializeApp();
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }

    return const AppEnvironment(firebaseReady: true);
  } catch (error) {
    return AppEnvironment(
      firebaseReady: false,
      firebaseError: error,
    );
  }
}
