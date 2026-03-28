enum SessionMode {
  practice,
  ranked,
}

class RankedSessionEnvelope {
  const RankedSessionEnvelope({
    required this.sessionId,
    required this.seasonId,
    required this.seed,
    required this.level,
    required this.levelBucket,
    required this.problemCount,
    required this.expiresAt,
    required this.balanceVersion,
  });

  final String sessionId;
  final String seasonId;
  final int seed;
  final int level;
  final String levelBucket;
  final int problemCount;
  final DateTime expiresAt;
  final String balanceVersion;

  factory RankedSessionEnvelope.fromMap(Map<String, dynamic> json) {
    return RankedSessionEnvelope(
      sessionId: json['sessionId'] as String,
      seasonId: json['seasonId'] as String,
      seed: (json['seed'] as num).toInt(),
      level: (json['level'] as num).toInt(),
      levelBucket: json['levelBucket'] as String,
      problemCount: (json['problemCount'] as num).toInt(),
      expiresAt: DateTime.fromMillisecondsSinceEpoch((json['expiresAt'] as num).toInt()),
      balanceVersion: json['balanceVersion'] as String,
    );
  }
}

class RankedSubmissionAnswer {
  const RankedSubmissionAnswer({
    required this.text,
    required this.elapsedMs,
    required this.strokeCount,
    required this.pointCount,
    required this.inkHash,
  });

  final String text;
  final int elapsedMs;
  final int strokeCount;
  final int pointCount;
  final String inkHash;

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'elapsedMs': elapsedMs,
      'strokeCount': strokeCount,
      'pointCount': pointCount,
      'inkHash': inkHash,
    };
  }
}

class RankedSubmissionResult {
  const RankedSubmissionResult({
    required this.attemptId,
    required this.brainScore,
    required this.accuracyRate,
    required this.comboMax,
    required this.correctCount,
  });

  final String attemptId;
  final int brainScore;
  final double accuracyRate;
  final int comboMax;
  final int correctCount;

  factory RankedSubmissionResult.fromMap(Map<String, dynamic> json) {
    return RankedSubmissionResult(
      attemptId: json['attemptId'] as String,
      brainScore: (json['brainScore'] as num).toInt(),
      accuracyRate: (json['accuracyRate'] as num).toDouble(),
      comboMax: (json['comboMax'] as num).toInt(),
      correctCount: (json['correctCount'] as num).toInt(),
    );
  }
}

class ProblemSubmissionRecord {
  const ProblemSubmissionRecord({
    required this.problemIndex,
    required this.submittedText,
    required this.expectedAnswer,
    required this.elapsedMs,
    required this.strokeCount,
    required this.pointCount,
    required this.inkHash,
    required this.correct,
  });

  final int problemIndex;
  final String submittedText;
  final String expectedAnswer;
  final int elapsedMs;
  final int strokeCount;
  final int pointCount;
  final String inkHash;
  final bool correct;

  RankedSubmissionAnswer toRankedAnswer() {
    return RankedSubmissionAnswer(
      text: submittedText,
      elapsedMs: elapsedMs,
      strokeCount: strokeCount,
      pointCount: pointCount,
      inkHash: inkHash,
    );
  }
}
