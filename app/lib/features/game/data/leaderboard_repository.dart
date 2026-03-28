import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/leaderboard_models.dart';

class LeaderboardRepository {
  LeaderboardRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const _seasonId = '2026_s1';

  Future<List<LeaderboardEntry>> loadTopEntries({
    required String scope,
    int limit = 5,
  }) async {
    final snapshotId = '${_seasonId}_${scope}_all_latest';
    final query = await _firestore
        .collection('leaderboard_snapshots')
        .doc(snapshotId)
        .collection('entries')
        .orderBy('rank')
        .limit(limit)
        .get();

    return query.docs
        .map((doc) => LeaderboardEntry.fromMap(doc.data()))
        .toList(growable: false);
  }
}
