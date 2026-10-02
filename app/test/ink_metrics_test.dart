import 'package:brain_math/features/ink/domain/ink_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  InkStrokeData stroke(List<List<double>> points) => InkStrokeData(
        points: points.map((p) => InkPointData(x: p[0], y: p[1], t: 0)).toList(),
      );

  test('counts strokes and points and hashes the shape', () {
    final metrics = InkMetrics.fromStrokes([
      stroke([
        [10, 10],
        [10, 40],
      ]),
      stroke([
        [20, 10],
        [30, 10],
        [30, 40],
      ]),
    ]);

    expect(metrics.strokeCount, 2);
    expect(metrics.pointCount, 5);
    expect(metrics.inkHash, hasLength(8));
  });

  test('hash ignores sub-grid jitter but changes with the shape', () {
    final base = InkMetrics.fromStrokes([
      stroke([
        [10, 10],
        [10, 40],
      ]),
    ]);
    final jitter = InkMetrics.fromStrokes([
      stroke([
        [10.5, 11],
        [11, 41],
      ]),
    ]);
    final other = InkMetrics.fromStrokes([
      stroke([
        [40, 10],
        [10, 40],
      ]),
    ]);

    expect(jitter.inkHash, base.inkHash);
    expect(other.inkHash, isNot(base.inkHash));
    expect(InkMetrics.fromStrokes(const []), same(InkMetrics.empty));
  });
}
