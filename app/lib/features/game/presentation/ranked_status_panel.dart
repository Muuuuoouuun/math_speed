import 'package:flutter/material.dart';

import '../application/game_session_controller.dart';
import '../domain/ranked_models.dart';
import 'paper_widgets.dart';

/// 랭크 세션의 준비/제출 상태와 서버가 확정한 공식 결과를 보여줍니다.
class RankedStatusPanel extends StatelessWidget {
  const RankedStatusPanel({
    required this.status,
    required this.result,
    required this.error,
    required this.canRetrySubmission,
    required this.onRetrySubmission,
    required this.onRestart,
    super.key,
  });

  final RankedRoundStatus status;
  final RankedSubmissionResult? result;
  final String? error;
  final bool canRetrySubmission;
  final VoidCallback onRetrySubmission;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (status) {
      case RankedRoundStatus.idle:
      case RankedRoundStatus.playing:
        return const SizedBox.shrink();
      case RankedRoundStatus.preparing:
        return const _BusyPanel(message: '랭크 문제지를 받아오는 중이에요');
      case RankedRoundStatus.submitting:
        return const _BusyPanel(message: '공식 기록을 채점하는 중이에요');
      case RankedRoundStatus.failed:
        return PaperPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('랭크 기록 오류', style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(error ?? '', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: canRetrySubmission ? onRetrySubmission : onRestart,
                child: Text(canRetrySubmission ? '다시 제출하기' : '랭크 다시 시작'),
              ),
            ],
          ),
        );
      case RankedRoundStatus.submitted:
        final official = result;
        if (official == null) return const SizedBox.shrink();
        final headline = official.flagged
            ? '기록 검토 중'
            : official.isNewBest
                ? '시즌 최고 기록!'
                : '공식 기록 저장 완료';
        final caption = official.flagged
            ? '진행 시간이 맞지 않아 이번 기록은 랭킹에 반영되지 않았어요.'
            : '학교와 지역 랭킹에 반영돼요. (같은 시즌 3판 이상부터 집계)';
        return PaperPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(headline, style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(caption, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: MetricTile(label: '공식 점수', value: '${official.brainScore}')),
                  Expanded(child: MetricTile(label: '시즌 최고', value: '${official.seasonBest}')),
                  Expanded(
                    child: MetricTile(
                      label: '정확도',
                      value: '${(official.accuracyRate * 100).toStringAsFixed(0)}%',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }
}

class _BusyPanel extends StatelessWidget {
  const _BusyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return PaperPanel(
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
