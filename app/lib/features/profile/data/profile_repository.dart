import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/player_profile.dart';

class ProfileRepository {
  ProfileRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  String? get currentUid => _auth.currentUser?.uid;

  Future<PlayerProfile?> loadCurrentProfile() async {
    final uid = currentUid;
    if (uid == null) {
      return null;
    }

    final snapshot = await _firestore.collection('users').doc(uid).get();
    if (!snapshot.exists) {
      return null;
    }

    return PlayerProfile.fromMap(uid, snapshot.data() ?? <String, dynamic>{});
  }

  Future<PlayerProfile> upsertProfile(ProfileDraft draft) async {
    final callable = _functions.httpsCallable('upsertPlayerProfile');
    final result = await callable.call<Map<String, dynamic>>({
      'displayName': draft.displayName,
      'schoolId': draft.schoolId,
      'regionCode': draft.regionCode,
      'grade': draft.grade,
    });

    final uid = currentUid;
    final data = Map<String, dynamic>.from(result.data);
    return PlayerProfile.fromMap(
      uid ?? (data['uid'] as String? ?? ''),
      data,
    );
  }
}

