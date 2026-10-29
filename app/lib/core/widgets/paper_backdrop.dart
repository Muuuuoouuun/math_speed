import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 화면 전체에 깔리는 종이 질감 배경.
///
/// 모눈 점, 종이 섬유 얼룩, 가장자리 그늘을 겹쳐서 스캔한 노트 위에
/// 올라간 것 같은 인상을 만듭니다. 텍스처는 시드가 고정되어 있어
/// 리빌드마다 얼룩이 튀지 않습니다.
class PaperBackdrop extends StatelessWidget {
  const PaperBackdrop({
    required this.child,
    this.showMarginLine = true,
    super.key,
  });

  final Widget child;

  /// 왼쪽 세로 여백선(공책의 빨간 줄)을 그릴지 여부.
  final bool showMarginLine;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _PaperPainter(showMarginLine: showMarginLine),
              isComplex: true,
              willChange: false,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _PaperPainter extends CustomPainter {
  const _PaperPainter({required this.showMarginLine});

  final bool showMarginLine;

  /// 얼룩 좌표는 한 번만 만들어 두고 재사용합니다.
  static final List<_Speck> _specks = _buildSpecks();

  static List<_Speck> _buildSpecks() {
    final random = math.Random(20240816);
    return List<_Speck>.generate(140, (_) {
      return _Speck(
        dx: random.nextDouble(),
        dy: random.nextDouble(),
        radius: 0.4 + (random.nextDouble() * 1.1),
        alpha: 0.02 + (random.nextDouble() * 0.045),
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1) 위에서 아래로 아주 옅게 어두워지는 종이 바탕.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFFDF8EC), AppPalette.paper, AppPalette.paperDeep],
          stops: <double>[0, 0.55, 1],
        ).createShader(rect),
    );

    // 2) 모눈 점. 너무 촘촘하면 지저분해서 28px 간격으로 둡니다.
    final dotPaint = Paint()..color = AppPalette.line.withValues(alpha: 0.55);
    const spacing = 28.0;
    for (var y = spacing; y < size.height; y += spacing) {
      for (var x = spacing; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 0.9, dotPaint);
      }
    }

    // 3) 종이 섬유 얼룩.
    for (final speck in _specks) {
      canvas.drawCircle(
        Offset(speck.dx * size.width, speck.dy * size.height),
        speck.radius,
        Paint()..color = AppPalette.graphite.withValues(alpha: speck.alpha),
      );
    }

    // 4) 공책 왼쪽 여백선.
    //    넓은 화면에서는 본문이 가운데로 모이므로, 선도 본문 기준으로 그어야
    //    한 장의 종이 위에 쓴 것처럼 보입니다.
    if (showMarginLine) {
      final contentWidth = math.min(
        size.width,
        AppSpacing.maxContentWidth + (AppSpacing.gutter * 2),
      );
      final contentLeft = (size.width - contentWidth) / 2;
      final marginX = contentLeft + math.min(contentWidth * 0.11, 46.0);
      canvas.drawLine(
        Offset(marginX, 0),
        Offset(marginX, size.height),
        Paint()
          ..color = AppPalette.margin.withValues(alpha: 0.32)
          ..strokeWidth = 1.4,
      );
    }

    // 5) 가장자리 그늘. 종이가 살짝 말려 올라간 느낌을 줍니다.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: <Color>[
            Colors.transparent,
            AppPalette.graphite.withValues(alpha: 0.05),
          ],
          stops: const <double>[0.65, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _PaperPainter oldDelegate) {
    return oldDelegate.showMarginLine != showMarginLine;
  }
}

class _Speck {
  const _Speck({
    required this.dx,
    required this.dy,
    required this.radius,
    required this.alpha,
  });

  final double dx;
  final double dy;
  final double radius;
  final double alpha;
}
