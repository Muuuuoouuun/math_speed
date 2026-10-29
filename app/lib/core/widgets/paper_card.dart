import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 노트에서 오려 붙인 종이 조각처럼 보이는 기본 패널.
///
/// 바깥 실선 테두리 안쪽에 바느질 자국 같은 점선을 한 겹 더 그려서
/// 아기자기한 인상을 만들고, 필요하면 위쪽에 마스킹 테이프를 붙입니다.
class PaperCard extends StatelessWidget {
  const PaperCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.accent,
    this.tapeLabel,
    this.stitched = true,
    this.elevated = true,
    this.tilt = 0,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// 카드 상단에 얇게 깔리는 색연필 띠. 없으면 그리지 않습니다.
  final Color? accent;

  /// 마스킹 테이프 위에 적을 짧은 문구.
  final String? tapeLabel;

  final bool stitched;
  final bool elevated;

  /// 라디안 단위 기울기. 손으로 붙인 듯한 미세한 각도를 줄 때 씁니다.
  final double tilt;

  @override
  Widget build(BuildContext context) {
    final accentColor = accent;

    Widget card = Container(
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppPalette.line, width: 1.3),
        boxShadow: elevated
            ? const <BoxShadow>[
                BoxShadow(color: AppPalette.shadow, blurRadius: 22, offset: Offset(0, 10)),
                BoxShadow(color: AppPalette.shadowSoft, blurRadius: 4, offset: Offset(0, 2)),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg - 1.3),
        child: CustomPaint(
          foregroundPainter: stitched ? const _StitchPainter() : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (accentColor != null)
                Container(height: 5, color: accentColor.withValues(alpha: 0.7)),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );

    if (tilt != 0) {
      card = Transform.rotate(angle: tilt, child: card);
    }

    final label = tapeLabel;
    if (label == null) {
      return card;
    }

    // 테이프가 카드 위쪽 테두리에 걸쳐 보이도록 여백을 미리 확보합니다.
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: <Widget>[
          card,
          Positioned(top: -12, child: WashiTape(label: label, color: accentColor)),
        ],
      ),
    );
  }
}

/// 카드 위에 붙는 마스킹 테이프 조각.
class WashiTape extends StatelessWidget {
  const WashiTape({
    required this.label,
    this.color,
    super.key,
  });

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base = color ?? AppPalette.apricot;
    return Transform.rotate(
      angle: -0.018,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: base.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(4),
          border: Border.symmetric(
            vertical: BorderSide(color: base.withValues(alpha: 0.34), width: 1.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: Color.lerp(base, AppPalette.ink, 0.55),
          ),
        ),
      ),
    );
  }
}

/// 카드 안쪽에 그려지는 바느질 자국 점선.
class _StitchPainter extends CustomPainter {
  const _StitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 40 || size.height < 40) return;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(7, 7, size.width - 14, size.height - 14),
      const Radius.circular(AppRadius.md),
    );
    final paint = Paint()
      ..color = AppPalette.line.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(dashPath(Path()..addRRect(rect), dash: 5, gap: 5), paint);
  }

  @override
  bool shouldRepaint(covariant _StitchPainter oldDelegate) => false;
}

/// 임의의 경로를 점선으로 잘라 낸 새 경로를 돌려줍니다.
Path dashPath(Path source, {double dash = 6, double gap = 5}) {
  final result = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final next = distance + dash;
      result.addPath(
        metric.extractPath(distance, next.clamp(0.0, metric.length)),
        Offset.zero,
      );
      distance = next + gap;
    }
  }
  return result;
}

/// 섹션 제목 위에 붙는 작은 라벨.
class SectionLabel extends StatelessWidget {
  const SectionLabel({
    required this.text,
    this.color,
    super.key,
  });

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppPalette.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: tint),
        ),
      ],
    );
  }
}
