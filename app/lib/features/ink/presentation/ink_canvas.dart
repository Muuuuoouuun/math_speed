import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/paper_card.dart';
import '../domain/ink_models.dart';

/// 손글씨를 받는 연습장 영역.
///
/// 획은 중간점을 지나는 2차 베지에로 이어 붙여 각지지 않게 만들고,
/// 같은 경로를 옅게 한 번 더 겹쳐 연필심이 번진 질감을 냅니다.
class InkCanvas extends StatefulWidget {
  const InkCanvas({
    required this.clearRevision,
    required this.onInkChanged,
    this.undoRevision = 0,
    this.hint = '여기에 답을 써 보세요',
    this.accent = AppPalette.mint,
    super.key,
  });

  /// 값이 바뀌면 모든 획을 지웁니다.
  final int clearRevision;

  /// 값이 바뀌면 마지막 획 하나만 지웁니다.
  final int undoRevision;

  /// 획 목록과 함께 캔버스 크기를 넘깁니다. 인식기는 필기 영역 크기를 알아야
  /// 글자 비율을 제대로 잡습니다.
  final void Function(List<InkStrokeData> strokes, Size canvasSize) onInkChanged;
  final String hint;
  final Color accent;

  @override
  State<InkCanvas> createState() => _InkCanvasState();
}

class _InkCanvasState extends State<InkCanvas> {
  final List<InkStrokeData> _strokes = <InkStrokeData>[];
  List<InkPointData> _activePoints = <InkPointData>[];

  /// 획 목록은 제자리에서 바뀌기 때문에 리스트 비교만으로는 다시 그릴 시점을
  /// 알 수 없습니다. 변경할 때마다 올리는 이 값으로 판단합니다.
  int _revision = 0;

  @override
  void didUpdateWidget(covariant InkCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.clearRevision != widget.clearRevision) {
      _strokes.clear();
      _activePoints = <InkPointData>[];
      _revision++;
      return;
    }

    if (oldWidget.undoRevision != widget.undoRevision && _strokes.isNotEmpty) {
      _strokes.removeLast();
      _activePoints = <InkPointData>[];
      _revision++;
      // 빌드 중에 부모 상태를 건드리지 않도록 프레임이 끝난 뒤에 알립니다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onInkChanged(List<InkStrokeData>.unmodifiable(_strokes), _canvasSize());
      });
    }
  }

  Size _canvasSize() {
    final box = context.findRenderObject() as RenderBox?;
    return box?.size ?? Size.zero;
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
    _revision++;
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
    _revision++;
    setState(() {});
  }

  void _endStroke([DragEndDetails? _]) {
    if (_activePoints.length < 2) {
      _activePoints = <InkPointData>[];
      _revision++;
      setState(() {});
      return;
    }

    _strokes.add(InkStrokeData(points: List<InkPointData>.unmodifiable(_activePoints)));
    _activePoints = <InkPointData>[];
    _revision++;
    widget.onInkChanged(List<InkStrokeData>.unmodifiable(_strokes), _canvasSize());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final previewStroke = _activePoints.length > 1 ? InkStrokeData(points: _activePoints) : null;
    final isEmpty = _strokes.isEmpty && previewStroke == null;

    return GestureDetector(
      onPanStart: _beginStroke,
      onPanUpdate: _appendPoint,
      onPanEnd: _endStroke,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _InkPainter(
            revision: _revision,
            strokes: _strokes,
            previewStroke: previewStroke,
            hint: isEmpty ? widget.hint : null,
            accent: widget.accent,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _InkPainter extends CustomPainter {
  const _InkPainter({
    required this.revision,
    required this.strokes,
    required this.previewStroke,
    required this.hint,
    required this.accent,
  });

  final int revision;
  final List<InkStrokeData> strokes;
  final InkStrokeData? previewStroke;
  final String? hint;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppRadius.md),
    );

    canvas.drawRRect(rrect, Paint()..color = AppPalette.cardSunk);
    canvas.save();
    canvas.clipRRect(rrect);

    _paintGuides(canvas, size);
    _paintHint(canvas, size);

    // Optimization: 입력 지연이 바로 체감되므로 획 목록만 다시 그리고,
    // 질감은 같은 경로를 한 번 더 옅게 겹치는 방식으로 싸게 처리합니다.
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }
    final preview = previewStroke;
    if (preview != null) {
      _drawStroke(canvas, preview);
    }

    canvas.restore();
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = AppPalette.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
  }

  void _paintGuides(Canvas canvas, Size size) {
    // 가로 괘선.
    final rulePaint = Paint()
      ..color = AppPalette.rule.withValues(alpha: 0.75)
      ..strokeWidth = 1;
    for (var y = 34.0; y < size.height - 10; y += 34) {
      canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), rulePaint);
    }

    // 글자를 앉힐 기준선과 안내 상자.
    final boxHeight = size.height * 0.56;
    final box = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.52,
      height: boxHeight,
    );
    canvas.drawPath(
      dashPath(
        Path()..addRRect(RRect.fromRectAndRadius(box, const Radius.circular(AppRadius.sm))),
        dash: 6,
        gap: 6,
      ),
      Paint()
        ..color = accent.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawLine(
      Offset(box.left + 10, box.bottom - (boxHeight * 0.18)),
      Offset(box.right - 10, box.bottom - (boxHeight * 0.18)),
      Paint()
        ..color = accent.withValues(alpha: 0.24)
        ..strokeWidth = 1.2,
    );

    // 모서리 장식.
    final cornerPaint = Paint()
      ..color = AppPalette.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    const inset = 12.0;
    const arm = 14.0;
    for (final corner in <List<Offset>>[
      <Offset>[const Offset(inset, inset + arm), const Offset(inset, inset), const Offset(inset + arm, inset)],
      <Offset>[
        Offset(size.width - inset - arm, inset),
        Offset(size.width - inset, inset),
        Offset(size.width - inset, inset + arm),
      ],
      <Offset>[
        Offset(inset, size.height - inset - arm),
        Offset(inset, size.height - inset),
        Offset(inset + arm, size.height - inset),
      ],
      <Offset>[
        Offset(size.width - inset - arm, size.height - inset),
        Offset(size.width - inset, size.height - inset),
        Offset(size.width - inset, size.height - inset - arm),
      ],
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(corner[0].dx, corner[0].dy)
          ..lineTo(corner[1].dx, corner[1].dy)
          ..lineTo(corner[2].dx, corner[2].dy),
        cornerPaint,
      );
    }
  }

  void _paintHint(Canvas canvas, Size size) {
    final text = hint;
    if (text == null || text.isEmpty) return;

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: AppPalette.faint.withValues(alpha: 0.85),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 40);

    painter.paint(
      canvas,
      Offset((size.width - painter.width) / 2, (size.height / 2) + (size.height * 0.20)),
    );
  }

  void _drawStroke(Canvas canvas, InkStrokeData stroke) {
    final points = stroke.points;
    if (points.length < 2) return;

    final path = _smoothPath(points);

    // 번짐 → 본선 순서로 겹쳐 연필 질감을 만듭니다.
    canvas.drawPath(
      path,
      Paint()
        ..color = AppPalette.ink.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF3A3630)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  Path _smoothPath(List<InkPointData> points) {
    final path = Path()..moveTo(points.first.x, points.first.y);
    if (points.length == 2) {
      path.lineTo(points[1].x, points[1].y);
      return path;
    }

    for (var i = 1; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      path.quadraticBezierTo(
        current.x,
        current.y,
        (current.x + next.x) / 2,
        (current.y + next.y) / 2,
      );
    }
    path.lineTo(points.last.x, points.last.y);
    return path;
  }

  @override
  bool shouldRepaint(covariant _InkPainter oldDelegate) {
    return oldDelegate.revision != revision ||
        oldDelegate.previewStroke != previewStroke ||
        oldDelegate.hint != hint ||
        oldDelegate.accent != accent;
  }
}
