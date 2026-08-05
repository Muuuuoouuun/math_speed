import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 앱 마스코트인 연필 캐릭터.
///
/// 이미지 에셋 없이 전부 캔버스로 그려서 어떤 해상도에서도 선이 뭉개지지
/// 않습니다. [bobbing]을 켜면 위아래로 천천히 흔들립니다.
class PencilMascot extends StatefulWidget {
  const PencilMascot({
    this.size = 96,
    this.bobbing = true,
    this.mood = MascotMood.happy,
    super.key,
  });

  final double size;
  final bool bobbing;
  final MascotMood mood;

  @override
  State<PencilMascot> createState() => _PencilMascotState();
}

enum MascotMood { happy, cheer, sleepy }

class _PencilMascotState extends State<PencilMascot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.bobbing) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant PencilMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bobbing && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.bobbing && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drawing = CustomPaint(
      size: Size(widget.size, widget.size * 1.4),
      painter: _PencilMascotPainter(mood: widget.mood),
    );

    if (!widget.bobbing) return drawing;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final curve = Curves.easeInOut.transform(_controller.value);
        return Transform.translate(
          offset: Offset(0, -4 + (curve * 8)),
          child: Transform.rotate(angle: -0.05 + (curve * 0.1), child: child),
        );
      },
      child: drawing,
    );
  }
}

class _PencilMascotPainter extends CustomPainter {
  const _PencilMascotPainter({required this.mood});

  final MascotMood mood;

  @override
  void paint(Canvas canvas, Size size) {
    // 100 x 140 기준으로 그린 뒤 실제 크기에 맞춰 확대합니다.
    final scale = math.min(size.width / 100, size.height / 140);
    canvas.save();
    canvas.translate((size.width - (100 * scale)) / 2, (size.height - (140 * scale)) / 2);
    canvas.scale(scale);

    final outline = Paint()
      ..color = AppPalette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // 바닥 그림자.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 146), width: 62, height: 12),
      Paint()..color = AppPalette.graphite.withValues(alpha: 0.10),
    );

    // 지우개.
    final eraser = RRect.fromRectAndCorners(
      const Rect.fromLTWH(28, 2, 44, 20),
      topLeft: const Radius.circular(11),
      topRight: const Radius.circular(11),
    );
    canvas.drawRRect(eraser, Paint()..color = AppPalette.blush.withValues(alpha: 0.9));
    canvas.drawRRect(eraser, outline);

    // 금속 밴드.
    const ferrule = Rect.fromLTWH(28, 22, 44, 10);
    canvas.drawRect(ferrule, Paint()..color = const Color(0xFFCFC6B6));
    canvas.drawRect(ferrule, outline);
    final bandPaint = Paint()
      ..color = AppPalette.graphite.withValues(alpha: 0.35)
      ..strokeWidth = 1.4;
    canvas.drawLine(const Offset(28, 26), const Offset(72, 26), bandPaint);
    canvas.drawLine(const Offset(28, 29.5), const Offset(72, 29.5), bandPaint);

    // 몸통.
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(28, 32, 44, 72),
      const Radius.circular(3),
    );
    canvas.drawRRect(body, Paint()..color = AppPalette.apricot.withValues(alpha: 0.92));
    // 왼쪽 하이라이트로 원통 느낌을 냅니다.
    canvas.drawRect(
      const Rect.fromLTWH(32, 32, 9, 72),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
    canvas.drawRect(
      const Rect.fromLTWH(63, 32, 6, 72),
      Paint()..color = AppPalette.graphite.withValues(alpha: 0.10),
    );
    canvas.drawRRect(body, outline);

    // 나무 깎인 부분과 흑연 심.
    final wood = Path()
      ..moveTo(28, 104)
      ..lineTo(50, 140)
      ..lineTo(72, 104)
      ..close();
    canvas.drawPath(wood, Paint()..color = const Color(0xFFEBD9B8));
    canvas.drawPath(wood, outline);

    final lead = Path()
      ..moveTo(41.5, 126)
      ..lineTo(50, 140)
      ..lineTo(58.5, 126)
      ..close();
    canvas.drawPath(lead, Paint()..color = AppPalette.ink);

    _paintFace(canvas, outline);
    canvas.restore();
  }

  void _paintFace(Canvas canvas, Paint outline) {
    final facePaint = Paint()..color = AppPalette.ink;
    final cheekPaint = Paint()..color = AppPalette.blush.withValues(alpha: 0.55);

    canvas.drawCircle(const Offset(36, 74), 4.2, cheekPaint);
    canvas.drawCircle(const Offset(64, 74), 4.2, cheekPaint);

    switch (mood) {
      case MascotMood.happy:
        canvas.drawCircle(const Offset(41, 64), 3.4, facePaint);
        canvas.drawCircle(const Offset(59, 64), 3.4, facePaint);
        canvas.drawArc(
          Rect.fromCenter(center: const Offset(50, 71), width: 18, height: 14),
          0.35,
          2.44,
          false,
          outline..strokeWidth = 2.4,
        );
      case MascotMood.cheer:
        // 눈을 ^ 모양으로 접어 웃는 표정.
        canvas.drawArc(
          Rect.fromCenter(center: const Offset(41, 66), width: 12, height: 10),
          math.pi + 0.3,
          2.54,
          false,
          outline..strokeWidth = 2.4,
        );
        canvas.drawArc(
          Rect.fromCenter(center: const Offset(59, 66), width: 12, height: 10),
          math.pi + 0.3,
          2.54,
          false,
          outline,
        );
        canvas.drawArc(
          Rect.fromCenter(center: const Offset(50, 72), width: 20, height: 18),
          0.3,
          2.54,
          false,
          outline,
        );
      case MascotMood.sleepy:
        canvas.drawLine(const Offset(36, 65), const Offset(46, 65), outline..strokeWidth = 2.4);
        canvas.drawLine(const Offset(54, 65), const Offset(64, 65), outline);
        canvas.drawArc(
          Rect.fromCenter(center: const Offset(50, 74), width: 12, height: 8),
          0.2,
          2.74,
          false,
          outline,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _PencilMascotPainter oldDelegate) => oldDelegate.mood != mood;
}

/// 손으로 그은 듯 살짝 흔들리는 밑줄.
class PencilRule extends StatelessWidget {
  const PencilRule({
    this.color,
    this.thickness = 2.4,
    this.height = 10,
    super.key,
  });

  final Color? color;
  final double thickness;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _PencilRulePainter(
          color: color ?? AppPalette.line,
          thickness: thickness,
        ),
      ),
    );
  }
}

class _PencilRulePainter extends CustomPainter {
  const _PencilRulePainter({required this.color, required this.thickness});

  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, size.height / 2);
    // 사인파를 아주 얕게 겹쳐 자로 대지 않고 그은 선처럼 보이게 합니다.
    for (var x = 0.0; x <= size.width; x += 6) {
      final wobble = math.sin(x / 26) * 1.1 + math.sin(x / 7) * 0.35;
      path.lineTo(x, (size.height / 2) + wobble);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PencilRulePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.thickness != thickness;
}

/// 정답 연출에 쓰는 네 갈래 반짝임.
class SparkleBurst extends StatelessWidget {
  const SparkleBurst({
    required this.progress,
    this.color = AppPalette.gold,
    super.key,
  });

  /// 0에서 1로 진행하는 애니메이션 값.
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SparklePainter(progress: progress, color: color));
  }
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * (0.28 + (progress * 0.34));
    final fade = (1 - progress).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = color.withValues(alpha: fade * 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 8; i++) {
      final angle = (math.pi / 4) * i;
      final inner = center + Offset(math.cos(angle), math.sin(angle)) * (radius * 0.62);
      final outer = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawLine(inner, outer, paint);
    }

    canvas.drawCircle(
      center,
      radius * 1.05,
      Paint()
        ..color = color.withValues(alpha: fade * 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
