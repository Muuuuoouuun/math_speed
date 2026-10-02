import 'game_mode.dart';

enum SessionMode {
  practice,
  ranked,
}

class RankedSessionEnvelope {
  const RankedSessionEnvelope({
    required this.sessionId,
    required this.seasonId,
    required this.seed,
    required this.mode,
    required this.levelBucket,
    required this.expiresAt,
    required this.balanceVersion,
  });

  final String sessionId;
  final String seasonId;
  final int seed;
  final GameMode mode;
  final String levelBucket;
  final DateTime expiresAt;
  final String balanceVersion;

  factory RankedSessionEnvelope.fromMap(Map<String, dynamic> json) {
    final mode = GameModeId.tryParse(json['mode'] as String?);
    if (mode == null) {
      throw FormatException('Unknown game mode: ${json['mode']}');
    }
    return RankedSessionEnvelope(
      sessionId: json['sessionId'] as String,
      seasonId: json['seasonId'] as String,
      seed: (json['seed'] as num).toInt(),
      mode: mode,
      levelBucket: json['levelBucket'] as String,
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
    required this.attemptCount,
    required this.seasonBest,
    required this.isNewBest,
    required this.flagged,
  });

  final String attemptId;
  final int brainScore;
  final double accuracyRate;
  final int comboMax;
  final int correctCount;
  final int attemptCount;
  final int seasonBest;
  final bool isNewBest;
  final bool flagged;

  factory RankedSubmissionResult.fromMap(Map<String, dynamic> json) {
    return RankedSubmissionResult(
      attemptId: json['attemptId'] as String,
      brainScore: (json['brainScore'] as num).toInt(),
      accuracyRate: (json['accuracyRate'] as num).toDouble(),
      comboMax: (json['comboMax'] as num).toInt(),
      correctCount: (json['correctCount'] as num).toInt(),
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
      seasonBest: (json['seasonBest'] as num?)?.toInt() ?? 0,
      isNewBest: json['isNewBest'] as bool? ?? false,
      flagged: json['flagged'] as bool? ?? false,
    );
  }
}

/// 한 문제에 대해 클라이언트가 채점한 기록입니다. 랭크 모드에서는 그대로 서버에 제출됩니다.
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
