class InkPointData {
  const InkPointData({
    required this.x,
    required this.y,
    required this.t,
  });

  final double x;
  final double y;
  final int t;
}

class InkStrokeData {
  const InkStrokeData({
    required this.points,
  });

  final List<InkPointData> points;
}

class InkMetrics {
  const InkMetrics({
    required this.strokeCount,
    required this.pointCount,
  });

  final int strokeCount;
  final int pointCount;

  static const empty = InkMetrics(strokeCount: 0, pointCount: 0);
}
