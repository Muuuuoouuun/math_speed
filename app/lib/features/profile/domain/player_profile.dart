class PlayerProfile {
  const PlayerProfile({
    required this.uid,
    required this.displayName,
    required this.schoolId,
    required this.regionCode,
    required this.grade,
    this.seasonBest = 0,
  });

  final String uid;
  final String displayName;
  final String schoolId;
  final String regionCode;
  final int grade;
  final int seasonBest;

  bool get isComplete =>
      displayName.trim().isNotEmpty &&
      schoolId.trim().isNotEmpty &&
      regionCode.trim().isNotEmpty &&
      grade > 0;

  factory PlayerProfile.fromMap(String uid, Map<String, dynamic> json) {
    return PlayerProfile(
      uid: uid,
      displayName: (json['displayName'] as String?) ?? '',
      schoolId: (json['schoolId'] as String?) ?? '',
      regionCode: (json['regionCode'] as String?) ?? '',
      grade: (json['grade'] as num?)?.toInt() ?? 0,
      seasonBest: (json['currentSeasonBest'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProfileDraft {
  const ProfileDraft({
    required this.displayName,
    required this.schoolId,
    required this.regionCode,
    required this.grade,
    this.seasonBest = 0,
  });

  final String displayName;
  final String schoolId;
  final String regionCode;
  final int grade;
  final int seasonBest;
}

