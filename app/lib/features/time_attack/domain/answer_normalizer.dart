/// 손글씨 인식 결과에서 숫자만 남깁니다.
///
/// 서버의 `normalizeAnswer`(functions/src/gameEngine.ts)와 같은 규칙을 따라야
/// 클라이언트 채점과 서버 공식 채점이 어긋나지 않습니다.
const Map<String, String> _lookalikeDigits = <String, String>{
  'O': '0',
  'o': '0',
  'D': '0',
  'l': '1',
  'I': '1',
  '|': '1',
  'Z': '2',
  'z': '2',
  'S': '5',
  's': '5',
  'b': '6',
  'g': '9',
  'q': '9',
};

String normalizeAnswer(String? value) {
  final buffer = StringBuffer();
  for (final rune in (value ?? '').runes) {
    final char = String.fromCharCode(rune);
    final mapped = _lookalikeDigits[char] ?? char;
    final code = mapped.codeUnitAt(0);
    if (mapped.length == 1 && code >= 0x30 && code <= 0x39) {
      buffer.write(mapped);
    } else if (mapped == '-' && buffer.isEmpty) {
      buffer.write(mapped);
    }
  }
  final result = buffer.toString();
  return result == '-' ? '' : result;
}
