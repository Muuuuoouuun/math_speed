class PlayerProfile {
  const PlayerProfile({
    required this.uid,
    required this.displayName,
    required this.schoolId,
    required this.regionCode,
    required this.grade,
  });

  final String uid;
  final String displayName;
  final String schoolId;
  final String regionCode;
  final int grade;

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
    );
  }
}

class ProfileDraft {
  const ProfileDraft({
    required this.displayName,
    required this.schoolId,
    required this.regionCode,
    required this.grade,
  });

  final String displayName;
  final String schoolId;
  final String regionCode;
  final int grade;
}

