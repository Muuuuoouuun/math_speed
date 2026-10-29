import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/bootstrap/app_environment.dart';
import '../../ink/application/digital_ink_service.dart';
import '../../ink/domain/ink_models.dart';
import '../../ink/presentation/ink_canvas.dart';
import '../../profile/domain/player_profile.dart';
import '../../profile/domain/profile_catalog.dart';
import '../application/game_session_controller.dart';
import '../domain/brain_score.dart';
import '../domain/game_mode.dart';

class BrainTrainingPage extends StatefulWidget {
  const BrainTrainingPage({
    required this.environment,
    this.profile,
    this.onProfileUpdated,
    super.key,
  });

  final AppEnvironment environment;
  final PlayerProfile? profile;
  final Future<void> Function()? onProfileUpdated;

  @override
  State<BrainTrainingPage> createState() => _BrainTrainingPageState();
}

class _BrainTrainingPageState extends State<BrainTrainingPage> {
  final GameSessionController _controller = GameSessionController();
  final DigitalInkService _digitalInkService = DigitalInkService(languageCode: 'ko');
  final TextEditingController _fallbackController = TextEditingController();
  Timer? _recognitionDebounce;

  @override
  void initState() {
    super.initState();
    _controller.startRound(mode: GameMode.simpleCalculation);
    unawaited(_warmupModel());
  }

  Future<void> _warmupModel() async {
    try {
      await _digitalInkService.ensureModelDownloaded();
    } catch (_) {
      // 모델 다운로드에 실패해도 수동 입력으로 끊김 없이 플레이할 수 있게 둡니다.
    }
  }

  @override
  void dispose() {
    _recognitionDebounce?.cancel();
    _fallbackController.dispose();
    _controller.dispose();
    unawaited(_digitalInkService.dispose());
    super.dispose();
  }

  Future<void> _handleInkChanged(List<InkStrokeData> strokes) async {
    final pointCount = strokes.fold<int>(0, (sum, stroke) => sum + stroke.points.length);
    _controller.updateInkMetrics(
      InkMetrics(
        strokeCount: strokes.length,
        pointCount: pointCount,
      ),
    );

    _recognitionDebounce?.cancel();
    _recognitionDebounce = Timer(const Duration(milliseconds: 90), () async {
      // Optimization: 손글씨 인식은 스트로크마다 바로 부르면 플랫폼 채널 왕복이 누적되므로 짧은 debounce로 지연과 배터리를 함께 줄입니다.
      final preview = await _digitalInkService.recognize(strokes);
      if (!mounted || preview == null) return;
      _controller.updateRecognitionPreview(preview.text);
    });
  }

  void _submitCurrentProblem() {
    final submitted = _controller.submitCurrentProblem();
    if (submitted) {
      _fallbackController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final profile = widget.profile;
        final current = _controller.currentProblem;
        final score = _controller.scoreBreakdown;
        final grade = _controller.performanceGrade;
        final progress = (_controller.timeLeftMs / _controller.gameModeConfig.maxTimeMs).clamp(0.0, 1.0);
        final lastAttemptCorrect = _controller.lastAttemptCorrect;
        final hasFeedback = lastAttemptCorrect != null && !_controller.isGameOver;
        final feedbackTitle = lastAttemptCorrect == true ? '참 잘했어요' : '다음 문제로 이어가요';
        final feedbackBody = lastAttemptCorrect == true
            ? '+${(_controller.lastBonusAwardedMs / 1000).toStringAsFixed(1)}초 보너스가 추가됐어요'
            : '정답은 ${_controller.lastExpectedAnswer ?? '-'}였어요';
        final submittedLabel = _controller.lastSubmittedAnswer.isEmpty ? '입력 없음' : _controller.lastSubmittedAnswer;

        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('연필 계산', style: theme.textTheme.headlineMedium),
                          const SizedBox(height: 6),
                          Text(
                            '시간 안에 최대한 많이 맞히고, 정답마다 남은 시간을 조금씩 되찾아 보세요.',
                            style: theme.textTheme.bodyMedium,
                          ),
                          if (profile != null) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _HeaderChip(label: profile.displayName),
                                _HeaderChip(label: schoolNameFor(profile.schoolId)),
                                _HeaderChip(label: regionNameFor(profile.regionCode)),
                                _HeaderChip(label: '학년 ${profile.grade}'),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _StatusPill(
                      label: widget.environment.firebaseReady ? 'online' : 'offline',
                      active: widget.environment.firebaseReady,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _PaperPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('남은 시간', style: theme.textTheme.bodyMedium),
                                const SizedBox(height: 6),
                                Text(
                                  '${_controller.formatTimeLeft()}초',
                                  style: theme.textTheme.headlineMedium?.copyWith(fontSize: 42),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_controller.gameModeConfig.label, style: theme.textTheme.titleLarge),
                                const SizedBox(height: 4),
                                Text(
                                  '정답 보너스 +${(_controller.gameModeConfig.bonusTimeMs / 1000).toStringAsFixed(1)}초',
                                  style: theme.textTheme.bodyMedium,
                                  textAlign: TextAlign.end,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 12,
                          backgroundColor: const Color(0xFFE7DED1),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF403C38)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _RuleTag(label: '시간 종료 시 게임 종료'),
                          _RuleTag(label: '정답마다 시간 회복'),
                          _RuleTag(label: '속도와 정확도로 등급 산정'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _PaperPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('모드 선택', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: GameModeConfig.all
                            .map(
                              (config) => ChoiceChip(
                                label: Text(config.label),
                                selected: _controller.gameMode == config.mode,
                                onSelected: (_) {
                                  _fallbackController.clear();
                                  _controller.setGameMode(config.mode);
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 10),
                      Text(_controller.gameModeConfig.description, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_controller.isGameOver)
                  _RoundSummary(
                    score: score,
                    gradeLabel: grade.label,
                    gradeCaption: grade.caption,
                    onRestart: () {
                      _fallbackController.clear();
                      _controller.restart();
                    },
                  )
                else ...[
                  if (hasFeedback) ...[
                    _StampCard(
                      title: feedbackTitle,
                      body: feedbackBody,
                      tone: lastAttemptCorrect == true ? _FeedbackTone.success : _FeedbackTone.retry,
                      trailing: lastAttemptCorrect == true ? '연속 ${_controller.currentCombo}' : submittedLabel,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _PaperPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('현재 문제', style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            current?.prompt ?? '-',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(fontSize: 44),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 252,
                          child: InkCanvas(
                            clearRevision: _controller.clearRevision,
                            onInkChanged: _handleInkChanged,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _InfoCard(
                                label: '인식값',
                                value: _controller.recognizedText.isEmpty ? '-' : _controller.recognizedText,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _InfoCard(
                                label: '현재 등급',
                                value: grade.label,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _InfoCard(
                                label: '획수',
                                value: '${_controller.currentInkMetrics.strokeCount}',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _InfoCard(
                                label: '포인트',
                                value: '${_controller.currentInkMetrics.pointCount}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _fallbackController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '수동 입력'),
                          onChanged: _controller.updateManualFallback,
                          onSubmitted: (_) => _submitCurrentProblem(),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: _submitCurrentProblem,
                                child: const Text('정답 확인'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  _fallbackController.clear();
                                  _controller.restart();
                                },
                                child: const Text('처음부터 다시'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _PaperPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('이번 라운드 기록', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: _Metric(label: '정답 수', value: '${score.correctCount}')),
                          Expanded(child: _Metric(label: '시도 수', value: '${score.attemptCount}')),
                          Expanded(child: _Metric(label: '정확도', value: '${(score.accuracyRate * 100).toStringAsFixed(0)}%')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _Metric(label: '분당 정답', value: score.correctPerMinute.toStringAsFixed(1))),
                          Expanded(child: _Metric(label: '연속 정답', value: '${_controller.currentCombo}')),
                          Expanded(child: _Metric(label: '보너스 시간', value: '+${(_controller.totalBonusMs / 1000).toStringAsFixed(1)}s')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _Metric(label: '최대 콤보', value: '${score.comboMax}')),
                          Expanded(child: _Metric(label: '두뇌 점수', value: '${score.brainScore}')),
                          Expanded(child: _Metric(label: '현재 등급', value: grade.label)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RoundSummary extends StatelessWidget {
  const _RoundSummary({
    required this.score,
    required this.gradeLabel,
    required this.gradeCaption,
    required this.onRestart,
  });

  final BrainScoreBreakdown score;
  final String gradeLabel;
  final String gradeCaption;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _PaperPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('라운드 종료', style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(
            gradeLabel,
            style: theme.textTheme.headlineMedium?.copyWith(fontSize: 42),
          ),
          const SizedBox(height: 6),
          Text(gradeCaption, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _Metric(label: '정답', value: '${score.correctCount}')),
              Expanded(child: _Metric(label: '시도', value: '${score.attemptCount}')),
              Expanded(child: _Metric(label: '정확도', value: '${(score.accuracyRate * 100).toStringAsFixed(0)}%')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Metric(label: '분당 정답', value: score.correctPerMinute.toStringAsFixed(1))),
              Expanded(child: _Metric(label: '최대 콤보', value: '${score.comboMax}')),
              Expanded(child: _Metric(label: '점수', value: '${score.brainScore}')),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onRestart,
            child: const Text('같은 모드로 다시 하기'),
          ),
        ],
      ),
    );
  }
}

class _PaperPanel extends StatelessWidget {
  const _PaperPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFD9D0C0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleLarge),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9D0C0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

enum _FeedbackTone {
  success,
  retry,
}

class _StampCard extends StatelessWidget {
  const _StampCard({
    required this.title,
    required this.body,
    required this.tone,
    required this.trailing,
  });

  final String title;
  final String body;
  final _FeedbackTone tone;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = tone == _FeedbackTone.success ? const Color(0xFF3B4436) : const Color(0xFF6B6258);
    final stampBackground = tone == _FeedbackTone.success ? const Color(0xFFE7EBDD) : const Color(0xFFF3ECE2);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD9D0C0)),
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: stampBackground,
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              tone == _FeedbackTone.success ? '도장' : '메모',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            trailing,
            style: theme.textTheme.titleLarge?.copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF35322F) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD9D0C0)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : const Color(0xFF7D766C),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD9D0C0)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF474440),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RuleTag extends StatelessWidget {
  const _RuleTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9D0C0)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF6B6258),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}



