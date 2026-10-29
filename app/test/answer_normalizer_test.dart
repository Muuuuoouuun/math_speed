import 'dart:convert';

import 'package:brain_math/features/game/domain/answer_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

/// 서버 `functions/src/answers.ts`의 normalizeAnswer를 실제로 실행해 뽑은 기준값입니다.
/// 한쪽 규칙을 바꾸면 다른 쪽도 같이 바꾸고 이 값을 다시 뽑아야 합니다.
const String _serverVectors = r'''
[
["", ""],
[" ", ""],
["12", "12"],
[" 12 ", "12"],
["1 2", "12"],
["12,", "12"],
["12.", "12"],
[".12", "12"],
["-7", "-7"],
["- 7", "-7"],
["−7", "7"],
["1２3", "13"],
["l2", "2"],
["O12", "12"],
["12개", "12"],
["3+4", "34"],
["007", "007"],
["  -  12  ", "-12"],
["12\n", "12"],
["\t9\t", "9"],
["１２", ""],
["abc", ""],
["4/2", "42"],
["(5)", "5"],
["12-", "12-"],
["--3", "--3"],
["5 . 0", "50"],
["1,000", "1000"],
["？12", "12"]
]
''';

void main() {
  final cases = (jsonDecode(_serverVectors) as List<dynamic>).cast<List<dynamic>>();

  test('정규화 규칙이 서버와 같다', () {
    expect(cases, isNotEmpty);
    for (final testCase in cases) {
      final input = testCase[0] as String;
      final expected = testCase[1] as String;
      expect(
        normalizeMathAnswer(input),
        expected,
        reason: '입력 ${jsonEncode(input)}에서 서버와 다르게 정리했습니다',
      );
    }
  });

  test('인식기가 흘린 기호는 답을 망치지 않는다', () {
    // 손글씨 인식이 자주 흘리는 형태들입니다.
    expect(normalizeMathAnswer('1 2'), '12');
    expect(normalizeMathAnswer('12,'), '12');
    expect(normalizeMathAnswer('12.'), '12');
    expect(normalizeMathAnswer('- 7'), '-7');
  });

  test('빈 값과 null은 빈 문자열이 된다', () {
    expect(normalizeMathAnswer(null), '');
    expect(normalizeMathAnswer('   '), '');
    expect(normalizeMathAnswer('abc'), '');
  });
}
