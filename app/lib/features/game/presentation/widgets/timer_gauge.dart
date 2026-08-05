import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

/// 남은 시간을 보여 주는 원형 게이지.
///
/// 눈금이 있는 아날로그 시계 모양을 기본으로 하고, 남은 시간이 줄어들수록
/// 게이지 색이 민트 → 살구 → 붉은 톤으로 넘어갑니다.
class TimerGauge extends StatelessWidget {
  const TimerGauge({
    required this.ratio,
    required this.timeText,
    required this.color,
    this.size = 152,
    this.caption = '남은 시간',
    this.pulse = 0,
    super.key,
  });

  /// 0~1 사이의 남은 시간 비율.
  final double ratio;
  final String timeText;
  final Color color;
  final double size;
  final String caption;

  /// 0~1 사이 값. 시간이 촉박할 때 게이지를 살짝 키우는 데 씁니다.
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: size,
      height: size,
      child: Transform.scale(
        scale: 1 + (pulse * 0.035),
        child: CustomPaint(
          painter: _GaugePainter(ratio: ratio, color: color),
          child: Center(
            // 남은 시간이 두 자리에서 세 자리로 늘거나 기기 글꼴이 커져도
            // 원 안에서 넘치지 않도록 줄여서 맞춥니다.
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.17),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      caption,
                      style: theme.textTheme.labelSmall?.copyWith(color: AppPalette.muted),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          timeText,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: size * 0.26,
                            color: AppPalette.ink,
                            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text('초', style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.ratio, required this.color});

  final double ratio;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 안쪽 종이 면.
    canvas.drawCircle(center, radius - 6, Paint()..color = AppPalette.card);
    canvas.drawCircle(
      center,
      radius - 6,
      Paint()
        ..color = AppPalette.lineSoft
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // 게이지 바닥 링.
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = AppPalette.paperDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9,
    );

    // 눈금. 12시 방향부터 30도 간격.
    final tickPaint = Paint()
      ..color = AppPalette.faint.withValues(alpha: 0.7)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final angle = (-math.pi / 2) + ((math.pi / 6) * i);
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + (direction * (radius - 13)),
        center + (direction * (radius - 8)),
        tickPaint,
      );
    }

    // 남은 시간 아크.
    if (ratio > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * ratio,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round,
      );

      // 아크 끝에 연필심 같은 점을 하나 찍어 진행 위치를 강조합니다.
      final headAngle = (-math.pi / 2) + (math.pi * 2 * ratio);
      final head = center + (Offset(math.cos(headAngle), math.sin(headAngle)) * radius);
      canvas.drawCircle(head, 6, Paint()..color = AppPalette.card);
      canvas.drawCircle(
        head,
        5,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.ratio != ratio || oldDelegate.color != color;
}
