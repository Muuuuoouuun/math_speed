import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/config/season_config.dart';
import '../application/game_session_controller.dart';
import '../domain/game_mode.dart';
import '../domain/ranked_models.dart';

class RankedSessionRepository implements RankedGateway {
  RankedSessionRepository({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _functions = functions ?? FirebaseFunctions.instanceFor(region: kFunctionsRegion),
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  Future<void> _ensureSignedIn() async {
    if (_auth.currentUser != null) {
      return;
    }

    await _auth.signInAnonymously();
  }

  @override
  Future<RankedSessionEnvelope> createRankedSession({
    required GameMode mode,
  }) async {
    await _ensureSignedIn();
    final callable = _functions.httpsCallable('createRankedSession');
    final result = await callable.call<Object?>({
      'mode': mode.id,
    });
    return RankedSessionEnvelope.fromMap(Map<String, dynamic>.from(result.data! as Map));
  }

  @override
  Future<RankedSubmissionResult> submitRankedSession({
    required String sessionId,
    required List<RankedSubmissionAnswer> answers,
  }) async {
    await _ensureSignedIn();
    final callable = _functions.httpsCallable('submitRankedSession');
    final result = await callable.call<Object?>({
      'sessionId': sessionId,
      'answers': answers.map((answer) => answer.toJson()).toList(growable: false),
    });
    return RankedSubmissionResult.fromMap(Map<String, dynamic>.from(result.data! as Map));
  }
}
