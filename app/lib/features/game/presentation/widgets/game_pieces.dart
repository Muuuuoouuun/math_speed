import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/paper_card.dart';
import '../../domain/game_mode.dart';

/// 시작 화면에서 고르는 난이도 카드.
///
/// 선택한 카드만 색연필 색으로 채워지고, 나머지는 옅은 종이 상태로 남습니다.
class ModeCard extends StatelessWidget {
  const ModeCard({
    required this.config,
    required this.accent,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final GameModeConfig config;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seconds = (config.initialTimeMs / 1000).round();

    return Semantics(
      button: true,
      selected: selected,
      label: '${config.label} 난이도',
      child: AnimatedContainer(
        duration: AppDuration.base,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.14) : AppPalette.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? accent : AppPalette.line,
            width: selected ? 2 : 1.3,
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
              child: Row(
                children: <Widget>[
                  _ModeGlyph(accent: accent, selected: selected, mode: config.mode),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(config.label, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 3),
                        Text(config.description, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text('$seconds초', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        '+${(config.bonusTimeMs / 1000).toStringAsFixed(1)}초',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
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

/// 난이도마다 다른 작은 도형 뱃지.
class _ModeGlyph extends StatelessWidget {
  const _ModeGlyph({
    required this.accent,
    required this.selected,
    required this.mode,
  });

  final Color accent;
  final bool selected;
  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    final symbol = switch (mode) {
      GameMode.simpleCalculation => '+',
      GameMode.fourOperations => '×',
      GameMode.doubleDigit => '2',
      GameMode.tripleDigit => '3',
    };

    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? accent : accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: accent.withValues(alpha: selected ? 1 : 0.4), width: 1.4),
      ),
      child: Text(
        symbol,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: selected ? Colors.white : Color.lerp(accent, AppPalette.ink, 0.35),
        ),
      ),
    );
  }
}

enum FeedbackTone { success, retry }

/// 정답/오답 직후에 잠깐 뜨는 도장 카드.
class FeedbackStamp extends StatelessWidget {
  const FeedbackStamp({
    required this.tone,
    required this.title,
    required this.body,
    required this.trailing,
    super.key,
  });

  final FeedbackTone tone;
  final String title;
  final String body;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = tone == FeedbackTone.success ? AppPalette.mint : AppPalette.blush;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.4),
      ),
      child: Row(
        children: <Widget>[
          Transform.rotate(
            angle: -0.12,
            child: Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppPalette.card,
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 2.2),
              ),
              child: Text(
                tone == FeedbackTone.success ? '정답' : '다시',
                style: TextStyle(
                  color: Color.lerp(accent, AppPalette.ink, 0.35),
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleMedium?.copyWith(color: AppPalette.ink)),
                const SizedBox(height: 2),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            trailing,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Color.lerp(accent, AppPalette.ink, 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// 결과 화면에서 쓰는 숫자 타일.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    this.accent,
    super.key,
  });

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = accent ?? AppPalette.graphite;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppPalette.cardSunk,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: AppPalette.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(color: tint),
            ),
          ),
        ],
      ),
    );
  }
}

/// 프로필/상태를 보여 주는 작은 알약 라벨.
class PaperChip extends StatelessWidget {
  const PaperChip({
    required this.label,
    this.color,
    this.filled = false,
    super.key,
  });

  final String label;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppPalette.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: filled ? tint.withValues(alpha: 0.16) : AppPalette.card,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: filled ? tint.withValues(alpha: 0.5) : AppPalette.line),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: filled ? Color.lerp(tint, AppPalette.ink, 0.3) : AppPalette.graphite,
        ),
      ),
    );
  }
}

/// 규칙 안내처럼 짧은 문장을 담는 메모 줄.
class NoteLine extends StatelessWidget {
  const NoteLine({
    required this.text,
    this.color,
    super.key,
  });

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppPalette.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// 섹션 제목 + 손그림 밑줄 묶음.
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    required this.label,
    required this.title,
    this.accent,
    super.key,
  });

  final String label;
  final String title;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionLabel(text: label, color: accent),
        const SizedBox(height: AppSpacing.xxs),
        Text(title, style: theme.textTheme.titleLarge),
      ],
    );
  }
}
