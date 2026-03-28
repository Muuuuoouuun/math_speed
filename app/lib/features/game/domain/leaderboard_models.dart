class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.entityId,
    required this.score,
    required this.eligibleUsers,
  });

  final int rank;
  final String entityId;
  final double score;
  final int eligibleUsers;

  factory LeaderboardEntry.fromMap(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num).toInt(),
      entityId: json['entityId'] as String,
      score: (json['score'] as num).toDouble(),
      eligibleUsers: (json['eligibleUsers'] as num?)?.toInt() ?? 0,
    );
  }
}
