import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/ranked_models.dart';

class RankedSessionRepository {
  RankedSessionRepository({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3'),
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  Future<void> _ensureSignedIn() async {
    if (_auth.currentUser != null) {
      return;
    }

    await _auth.signInAnonymously();
  }

  Future<RankedSessionEnvelope> createRankedSession({
    required int level,
  }) async {
    await _ensureSignedIn();
    final callable = _functions.httpsCallable('createRankedSession');
    final result = await callable.call<Map<String, dynamic>>({
      'level': level,
    });
    return RankedSessionEnvelope.fromMap(Map<String, dynamic>.from(result.data));
  }

  Future<RankedSubmissionResult> submitRankedSession({
    required String sessionId,
    required List<RankedSubmissionAnswer> answers,
  }) async {
    await _ensureSignedIn();
    final callable = _functions.httpsCallable('submitRankedSession');
    final result = await callable.call<Map<String, dynamic>>({
      'sessionId': sessionId,
      'answers': answers.map((answer) => answer.toJson()).toList(growable: false),
    });
    return RankedSubmissionResult.fromMap(Map<String, dynamic>.from(result.data));
  }
}
