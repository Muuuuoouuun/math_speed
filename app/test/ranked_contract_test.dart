import 'dart:convert';

import 'package:brain_math/features/game/domain/ranked_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// 아래 두 덩어리는 Firebase 에뮬레이터에 올린 실제 Cloud Functions가 돌려준
/// 응답을 그대로 붙여 넣은 것입니다. 서버가 필드 이름이나 타입을 바꾸면
/// 이 테스트가 먼저 깨집니다.
///
/// 다시 뽑는 방법:
///   cd functions && npm run build
///   npx firebase emulators:start --only functions,firestore,auth --project brain-math-dev
///   (익명 로그인 → upsertPlayerProfile → createRankedSession → submitRankedSession)
const String _createRankedSessionResponse = r'''
{
  "sessionId": "Y5Qp1aHTXTKczHowvfvi",
  "seasonId": "2026_s1",
  "seed": 1423023349,
  "level": 5,
  "levelBucket": "level-5",
  "problemCount": 14,
  "expiresAt": 1787048641694,
  "balanceVersion": "game_balance_v1"
}
''';

const String _submitRankedSessionResponse = r'''
{
  "attemptId": "3kvG99lkqyd3NTJeQW6W",
  "brainScore": 3401,
  "accuracyRate": 0.9285714285714286,
  "comboMax": 12,
  "correctCount": 13
}
''';

void main() {
  test('createRankedSession 응답을 그대로 파싱한다', () {
    final json = jsonDecode(_createRankedSessionResponse) as Map<String, dynamic>;
    final envelope = RankedSessionEnvelope.fromMap(json);

    expect(envelope.sessionId, isNotEmpty);
    expect(envelope.seasonId, '2026_s1');
    expect(envelope.seed, greaterThan(0));
    expect(envelope.level, inInclusiveRange(1, 10));
    expect(envelope.levelBucket, 'level-${envelope.level}');
    expect(envelope.balanceVersion, isNotEmpty);

    // 서버는 problemCount를 레벨에 따라 정합니다. 클라이언트가 임의로 정하면
    // 시드가 달라져 전부 오답이 됩니다.
    expect(envelope.problemCount, greaterThanOrEqualTo(5));
    expect(envelope.problemCount, lessThanOrEqualTo(30));

    // 만료 시각은 밀리초 정수로 옵니다.
    expect(
      envelope.expiresAt.millisecondsSinceEpoch,
      (json['expiresAt'] as num).toInt(),
    );
  });

  test('submitRankedSession 응답을 그대로 파싱한다', () {
    final json = jsonDecode(_submitRankedSessionResponse) as Map<String, dynamic>;
    final result = RankedSubmissionResult.fromMap(json);

    expect(result.attemptId, isNotEmpty);
    expect(result.brainScore, greaterThan(0));
    expect(result.accuracyRate, inInclusiveRange(0, 1));
    expect(result.comboMax, greaterThanOrEqualTo(0));
    expect(result.correctCount, greaterThanOrEqualTo(0));
  });

  test('클라이언트가 보내는 답 형식이 서버가 읽는 필드와 같다', () {
    const answer = RankedSubmissionAnswer(
      text: '42',
      elapsedMs: 1500,
      strokeCount: 3,
      pointCount: 42,
      inkHash: 'abcd1234',
    );

    // functions/src/index.ts의 SubmitAnswer 타입이 읽는 키들입니다.
    expect(
      answer.toJson().keys.toSet(),
      <String>{'text', 'elapsedMs', 'strokeCount', 'pointCount', 'inkHash'},
    );
  });
}
