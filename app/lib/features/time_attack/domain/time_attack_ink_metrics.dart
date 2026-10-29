import '../../ink/domain/ink_models.dart';

class TimeAttackInkMetrics {
  const TimeAttackInkMetrics({
    required this.strokeCount,
    required this.pointCount,
    this.inkHash = '',
  });

  final int strokeCount;
  final int pointCount;

  /// 획 모양을 4px 격자로 양자화해 만든 FNV-1a 해시입니다.
  /// 동일한 잉크를 반복 제출하는 패턴을 서버 분석에서 찾기 위한 용도이며, 원본 잉크는 보내지 않습니다.
  final String inkHash;

  static const empty = TimeAttackInkMetrics(strokeCount: 0, pointCount: 0);

  factory TimeAttackInkMetrics.fromStrokes(List<InkStrokeData> strokes) {
    if (strokes.isEmpty) return empty;

    const fnvPrime = 0x01000193;
    var hash = 0x811C9DC5;
    void mix(int value) {
      hash ^= value & 0xFFFF;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }

    var pointCount = 0;
    for (final stroke in strokes) {
      mix(0xFFFF);
      for (final point in stroke.points) {
        mix(point.x ~/ 4);
        mix(point.y ~/ 4);
      }
      pointCount += stroke.points.length;
    }

    return TimeAttackInkMetrics(
      strokeCount: strokes.length,
      pointCount: pointCount,
      inkHash: hash.toRadixString(16).padLeft(8, '0'),
    );
  }
}
