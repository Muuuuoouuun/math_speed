/**
 * 제출된 답에서 숫자와 음수 부호만 남깁니다.
 *
 * 손글씨 인식기는 쉼표나 마침표처럼 사람 눈에 잘 안 띄는 기호를 함께 돌려줄 때가
 * 있어서, 채점 전에 한 번 훑어 냅니다.
 *
 * 클라이언트도 같은 규칙을 써야 합니다.
 * 대응 구현: `app/lib/features/game/domain/answer_normalizer.dart`
 */
export function normalizeAnswer(value: string | undefined): string {
  return (value ?? '').replace(/\s+/g, '').replace(/[^\d-]/g, '');
}
