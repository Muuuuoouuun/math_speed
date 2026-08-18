/// 제출된 답에서 숫자와 음수 부호만 남깁니다.
///
/// 손글씨 인식기는 쉼표나 마침표처럼 사람 눈에 잘 안 띄는 기호를 함께 돌려줄 때가
/// 있습니다. 그대로 비교하면 맞게 쓴 답이 오답이 됩니다.
///
/// 서버가 채점 직전에 같은 정리를 하기 때문에, 클라이언트도 똑같이 정리해야
/// 화면에 보여 주는 판정과 서버가 매기는 점수가 어긋나지 않습니다.
/// 대응 구현: `functions/src/answers.ts`
String normalizeMathAnswer(String? value) {
  return (value ?? '').replaceAll(_whitespace, '').replaceAll(_notDigitOrMinus, '');
}

final RegExp _whitespace = RegExp(r'\s+');
final RegExp _notDigitOrMinus = RegExp(r'[^\d-]');
