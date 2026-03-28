import 'package:flutter/material.dart';

import '../domain/ink_models.dart';

class InkCanvas extends StatefulWidget {
  const InkCanvas({
    required this.clearRevision,
    required this.onInkChanged,
    super.key,
  });

  final int clearRevision;
  final ValueChanged<List<InkStrokeData>> onInkChanged;

  @override
  State<InkCanvas> createState() => _InkCanvasState();
}

class _InkCanvasState extends State<InkCanvas> {
  final List<InkStrokeData> _strokes = <InkStrokeData>[];
  List<InkPointData> _activePoints = <InkPointData>[];

  @override
  void didUpdateWidget(covariant InkCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clearRevision != widget.clearRevision) {
      _strokes.clear();
      _activePoints = <InkPointData>[];
    }
  }

  void _beginStroke(DragStartDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    final localPosition = box?.globalToLocal(details.globalPosition) ?? Offset.zero;
    _activePoints = <InkPointData>[
      InkPointData(
        x: localPosition.dx,
        y: localPosition.dy,
        t: DateTime.now().millisecondsSinceEpoch,
      ),
    ];
    setState(() {});
  }

  void _appendPoint(DragUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    final localPosition = box?.globalToLocal(details.globalPosition) ?? Offset.zero;
    _activePoints = <InkPointData>[
      ..._activePoints,
      InkPointData(
        x: localPosition.dx,
        y: localPosition.dy,
        t: DateTime.now().millisecondsSinceEpoch,
      ),
    ];
    setState(() {});
  }

  void _endStroke([DragEndDetails? _]) {
    if (_activePoints.length < 2) {
      _activePoints = <InkPointData>[];
      setState(() {});
      return;
    }

    _strokes.add(InkStrokeData(points: List<InkPointData>.unmodifiable(_activePoints)));
    _activePoints = <InkPointData>[];
    widget.onInkChanged(List<InkStrokeData>.unmodifiable(_strokes));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final previewStroke = _activePoints.length > 1 ? InkStrokeData(points: _activePoints) : null;
    return GestureDetector(
      onPanStart: _beginStroke,
      onPanUpdate: _appendPoint,
      onPanEnd: _endStroke,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _InkPainter(
            strokes: _strokes,
            previewStroke: previewStroke,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _InkPainter extends CustomPainter {
  const _InkPainter({
    required this.strokes,
    required this.previewStroke,
  });

  final List<InkStrokeData> strokes;
  final InkStrokeData? previewStroke;

  @override
  void paint(Canvas canvas, Size size) {
    final paperPaint = Paint()..color = const Color(0xFFFFFCF6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24)),
      paperPaint,
    );

    final marginPaint = Paint()
      ..color = const Color(0xFFD8CBC6)
      ..strokeWidth = 1.2;
    final linePaint = Paint()
      ..color = const Color(0xFFE7DED1)
      ..strokeWidth = 1;
    final hatchPaint = Paint()
      ..color = const Color(0x14000000)
      ..strokeWidth = 1;

    for (var x = -size.height; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), hatchPaint);
    }

    canvas.drawLine(const Offset(34, 18), Offset(34, size.height - 18), marginPaint);

    for (var y = 28.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(18, y), Offset(size.width - 18, y), linePaint);
    }

    final strokePaint = Paint()
      ..color = const Color(0xFF4A4743)
      ..strokeWidth = 4.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Optimization: 입력 지연이 바로 체감되므로, 캔버스는 현재 스트로크 목록만 다시 그리도록 단순한 선분 루프를 유지합니다.
    for (final stroke in strokes) {
      _drawStroke(canvas, strokePaint, stroke);
    }

    if (previewStroke != null) {
      _drawStroke(canvas, strokePaint, previewStroke!);
    }
  }

  void _drawStroke(Canvas canvas, Paint paint, InkStrokeData stroke) {
    if (stroke.points.length < 2) return;
    for (var i = 1; i < stroke.points.length; i++) {
      final previous = stroke.points[i - 1];
      final current = stroke.points[i];
      canvas.drawLine(
        Offset(previous.x, previous.y),
        Offset(current.x, current.y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _InkPainter oldDelegate) {
    return oldDelegate.strokes != strokes || oldDelegate.previewStroke != previewStroke;
  }
}
