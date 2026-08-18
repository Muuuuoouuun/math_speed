import 'ink_models.dart';

/// 획 좌표를 짧은 지문으로 줄입니다.
///
/// 서버는 이 값을 그대로 저장해 두었다가 나중에 같은 필기가 반복 제출되는지
/// 보는 용도로만 씁니다. 원본 좌표를 보내지 않아도 되도록 FNV-1a로 접습니다.
String inkHashOf(List<InkStrokeData> strokes) {
  var hash = 0x811C9DC5;

  void fold(int value) {
    hash ^= value & 0xFFFF;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }

  for (final stroke in strokes) {
    fold(stroke.points.length);
    for (final point in stroke.points) {
      fold(point.x.round());
      fold(point.y.round());
    }
  }

  return hash.toRadixString(16).padLeft(8, '0');
}
