import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/bootstrap/app_environment.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/paper_backdrop.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../core/widgets/pencil_doodles.dart';
import '../../ink/application/digital_ink_service.dart';
import '../../ink/domain/ink_models.dart';
import '../../ink/presentation/ink_canvas.dart';
import '../../profile/domain/player_profile.dart';
import '../../profile/domain/profile_catalog.dart';
import '../application/game_session_controller.dart';
import '../domain/game_mode.dart';
import 'widgets/game_pieces.dart';
import 'widgets/timer_gauge.dart';

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

class _BrainTrainingPageState extends State<BrainTrainingPage> with TickerProviderStateMixin {
  final GameSessionController _controller = GameSessionController();
  final DigitalInkService _digitalInkService = DigitalInkService(languageCode: 'ko');
  final TextEditingController _fallbackController = TextEditingController();

  Timer? _recognitionDebounce;
  Timer? _countdownTimer;

  /// 되돌리기를 누른 횟수. 캔버스는 이 값이 바뀔 때 마지막 획을 지웁니다.
  int _undoRevision = 0;

  /// 3-2-1 카운트다운. null이면 표시하지 않습니다.
  int? _countdown;

  // 지연 초기화로 두면 시작 화면만 보고 나갔을 때 dispose 시점에 컨트롤러가
  // 처음 만들어지면서 터집니다. initState에서 미리 만들어 둡니다.
  late final AnimationController _sparkleController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _sparkleController = AnimationController(
      vsync: this,
      duration: AppDuration.stamp,
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    unawaited(_warmupModel());
  }

  Future<void> _warmupModel() async {
    try {
      await _digitalInkService.ensureModelDownloaded();
    } catch (_) {
      // 모델 다운로드에 실패해도 직접 입력으로 계속 진행할 수 있게 조용히 넘어갑니다.
    }
  }

  @override
  void dispose() {
    _recognitionDebounce?.cancel();
    _countdownTimer?.cancel();
    _sparkleController.dispose();
    _pulseController.dispose();
    _fallbackController.dispose();
    _controller.dispose();
    unawaited(_digitalInkService.dispose());
    super.dispose();
  }

  Color get _accent => AppPalette.crayons[_controller.gameMode.index % AppPalette.crayons.length];

  Future<void> _handleInkChanged(List<InkStrokeData> strokes, Size canvasSize) async {
    final pointCount = strokes.fold<int>(0, (sum, stroke) => sum + stroke.points.length);
    _controller.updateInkMetrics(
      InkMetrics(strokeCount: strokes.length, pointCount: pointCount),
    );

    _recognitionDebounce?.cancel();
    _recognitionDebounce = Timer(const Duration(milliseconds: 90), () async {
      // Optimization: 손글씨 인식을 획마다 바로 부르면 플러그인 채널이 밀리므로
      // 짧은 debounce로 마지막 입력만 넘깁니다.
      final preview = await _digitalInkService.recognize(
        strokes,
        writingAreaWidth: canvasSize.width,
        writingAreaHeight: canvasSize.height,
      );
      if (!mounted || preview == null) return;
      _controller.updateRecognitionPreview(preview.text);
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdown = 3);
    unawaited(HapticFeedback.lightImpact());

    _countdownTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      final next = (_countdown ?? 1) - 1;
      if (next <= 0) {
        timer.cancel();
        setState(() => _countdown = null);
        _fallbackController.clear();
        _controller.startRound(mode: _controller.gameMode);
        return;
      }
      setState(() => _countdown = next);
      unawaited(HapticFeedback.selectionClick());
    });
  }

  void _submitCurrentProblem() {
    final submitted = _controller.submitCurrentProblem();
    if (!submitted) return;

    _fallbackController.clear();
    if (_controller.lastAttemptCorrect == true) {
      _sparkleController.forward(from: 0);
      unawaited(HapticFeedback.mediumImpact());
    } else {
      unawaited(HapticFeedback.heavyImpact());
    }
  }

  void _restart() {
    _fallbackController.clear();
    _controller.restart();
  }

  void _quitToReady() {
    _countdownTimer?.cancel();
    _fallbackController.clear();
    setState(() => _countdown = null);
    _controller.returnToReady();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PaperBackdrop(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Stack(
                children: <Widget>[
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
                      child: AnimatedSwitcher(
                        duration: AppDuration.base,
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeIn,
                        child: _buildPhaseView(context),
                      ),
                    ),
                  ),
                  if (_countdown != null) _CountdownOverlay(value: _countdown!, accent: _accent),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseView(BuildContext context) {
    switch (_controller.phase) {
      case RoundPhase.ready:
        return _buildReadyView(context);
      case RoundPhase.playing:
        return _buildPlayingView(context);
      case RoundPhase.finished:
        return _buildSummaryView(context);
    }
  }

  // --------------------------------------------------------------- 시작 화면

  Widget _buildReadyView(BuildContext context) {
    final theme = Theme.of(context);
    final profile = widget.profile;
    final accent = _accent;

    return ListView(
      key: const ValueKey<String>('ready'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        _TopBar(
          online: widget.environment.firebaseReady,
          trailing: profile == null
              ? null
              : PaperChip(label: profile.displayName, color: accent, filled: true),
        ),
        const SizedBox(height: AppSpacing.xl),

        // 표지. 마스코트와 제목만 두고 주변을 넉넉히 비웠습니다.
        PaperCard(
          accent: accent,
          tapeLabel: '오늘의 연습',
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            children: <Widget>[
              const PencilMascot(size: 92),
              const SizedBox(height: AppSpacing.md),
              Text('연필 계산', style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xxs),
              SizedBox(
                width: 132,
                child: PencilRule(color: accent.withValues(alpha: 0.55)),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '연필로 또박또박 쓰면서\n계산 속도를 늘려 보는 연습장이에요.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: AppPalette.graphite),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  PaperChip(label: '맞히면 시간 회복'),
                  PaperChip(label: '연속 정답 보너스'),
                  PaperChip(label: '손글씨 그대로 채점'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        const SectionHeading(label: 'STEP 1', title: '난이도를 골라요'),
        const SizedBox(height: AppSpacing.sm),
        ...GameModeConfig.all.map((config) {
          final crayon = AppPalette.crayons[config.mode.index % AppPalette.crayons.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: ModeCard(
              config: config,
              accent: crayon,
              selected: _controller.gameMode == config.mode,
              onTap: () {
                unawaited(HapticFeedback.selectionClick());
                _controller.setGameMode(config.mode);
              },
            ),
          );
        }),
        const SizedBox(height: AppSpacing.lg),

        const SectionHeading(label: 'STEP 2', title: '규칙은 이렇게'),
        const SizedBox(height: AppSpacing.sm),
        const PaperCard(
          stitched: false,
          elevated: false,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              NoteLine(text: '시간이 0이 되면 그 판은 끝나요.'),
              NoteLine(text: '정답을 맞힐 때마다 시간이 조금씩 돌아와요.'),
              NoteLine(text: '속도와 정확도를 함께 봐서 등급을 매겨요.'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        FilledButton(
          onPressed: _startCountdown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.play_arrow_rounded, size: 22),
              const SizedBox(width: AppSpacing.xs),
              Text('${_controller.gameModeConfig.label} 시작하기'),
            ],
          ),
        ),

        if (profile != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.center,
            children: <Widget>[
              PaperChip(label: schoolNameFor(profile.schoolId)),
              PaperChip(label: regionNameFor(profile.regionCode)),
              PaperChip(label: '${profile.grade}학년'),
            ],
          ),
        ],
      ],
    );
  }

  // -------------------------------------------------------------- 플레이 화면

  Widget _buildPlayingView(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accent;
    final ratio = _controller.timeRatio;
    final urgency = urgencyColor(ratio);
    final current = _controller.currentProblem;
    final score = _controller.scoreBreakdown;
    final answerPreview = _controller.recognizedText.isNotEmpty
        ? _controller.recognizedText
        : (_controller.manualFallback.isNotEmpty ? _controller.manualFallback : null);
    final hasInk = _controller.currentInkMetrics.strokeCount > 0;

    return ListView(
      key: const ValueKey<String>('playing'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        Row(
          children: <Widget>[
            PaperChip(label: _controller.gameModeConfig.label, color: accent, filled: true),
            if (_controller.currentCombo >= 2) ...<Widget>[
              const SizedBox(width: AppSpacing.xxs),
              PaperChip(
                label: '${_controller.currentCombo}연속',
                color: AppPalette.gold,
                filled: true,
              ),
            ],
            const Spacer(),
            TextButton.icon(
              onPressed: _quitToReady,
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('그만두기'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // 시계. 위아래 여백을 크게 둬서 시선이 먼저 여기에 닿게 합니다.
        Center(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final pulse = ratio < 0.25 ? _pulseController.value : 0.0;
              return TimerGauge(
                ratio: ratio,
                timeText: _controller.formatTimeLeft(),
                color: urgency,
                pulse: pulse,
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // 문제.
        Stack(
          alignment: Alignment.center,
          children: <Widget>[
            PaperCard(
              accent: accent,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xl,
              ),
              child: Column(
                children: <Widget>[
                  SectionLabel(text: '${score.attemptCount + 1}번째 문제', color: accent),
                  const SizedBox(height: AppSpacing.md),
                  AnimatedSwitcher(
                    duration: AppDuration.quick,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.18),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: FittedBox(
                      key: ValueKey<String>(current?.prompt ?? '-'),
                      fit: BoxFit.scaleDown,
                      child: Text(
                        current?.prompt ?? '-',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displayLarge,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _sparkleController,
                  builder: (context, _) => SparkleBurst(progress: _sparkleController.value),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // 직전 채점 결과.
        AnimatedSize(
          duration: AppDuration.base,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _buildFeedback(),
        ),

        // 연습장.
        PaperCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  SectionLabel(text: '연습장', color: accent),
                  const Spacer(),
                  _ToolButton(
                    icon: Icons.undo_rounded,
                    label: '되돌리기',
                    onTap: hasInk ? () => setState(() => _undoRevision++) : null,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  _ToolButton(
                    icon: Icons.cleaning_services_rounded,
                    label: '지우기',
                    onTap: hasInk ? _controller.clearInk : null,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 248,
                child: InkCanvas(
                  clearRevision: _controller.clearRevision,
                  undoRevision: _undoRevision,
                  onInkChanged: _handleInkChanged,
                  accent: accent,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(child: _AnswerPreview(value: answerPreview, accent: accent)),
                  const SizedBox(width: AppSpacing.xs),
                  SizedBox(
                    width: 118,
                    child: TextField(
                      controller: _fallbackController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        hintText: '직접 입력',
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 17),
                      ),
                      onChanged: _controller.updateManualFallback,
                      onSubmitted: (_) => _submitCurrentProblem(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        FilledButton(
          onPressed: _submitCurrentProblem,
          style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
          child: const Text('정답 확인'),
        ),
        const SizedBox(height: AppSpacing.lg),

        // 가벼운 현황 요약. 세부 지표는 결과 화면에서 몰아서 보여 줍니다.
        // 스크롤 안에서는 세로가 무한이라 stretch를 쓰려면 IntrinsicHeight가 필요합니다.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: StatTile(label: '맞힌 문제', value: '${score.correctCount}')),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: StatTile(
                  label: '정확도',
                  value: '${(score.accuracyRate * 100).toStringAsFixed(0)}%',
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: StatTile(
                  label: '회복한 시간',
                  value: '+${(_controller.totalBonusMs / 1000).toStringAsFixed(1)}초',
                  accent: AppPalette.mint,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeedback() {
    final correct = _controller.lastAttemptCorrect;
    if (correct == null) {
      return const SizedBox(width: double.infinity);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: FeedbackStamp(
        key: ValueKey<int>(_controller.attemptCount),
        tone: correct ? FeedbackTone.success : FeedbackTone.retry,
        title: correct ? '잘했어요!' : '아쉬워요',
        body: correct
            ? '+${(_controller.lastBonusAwardedMs / 1000).toStringAsFixed(1)}초를 돌려받았어요'
            : '정답은 ${_controller.lastExpectedAnswer ?? '-'}였어요',
        trailing: correct
            ? '${_controller.currentCombo}연속'
            : (_controller.lastSubmittedAnswer.isEmpty ? '-' : _controller.lastSubmittedAnswer),
      ),
    );
  }

  // --------------------------------------------------------------- 결과 화면

  Widget _buildSummaryView(BuildContext context) {
    final theme = Theme.of(context);
    final score = _controller.scoreBreakdown;
    final grade = _controller.performanceGrade;
    final accent = _accent;
    final mood = score.accuracyRate >= 0.8 ? MascotMood.cheer : MascotMood.sleepy;

    return ListView(
      key: const ValueKey<String>('summary'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        _TopBar(online: widget.environment.firebaseReady),
        const SizedBox(height: AppSpacing.xl),
        PaperCard(
          accent: accent,
          tapeLabel: '한 판 끝',
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            children: <Widget>[
              PencilMascot(size: 84, mood: mood),
              const SizedBox(height: AppSpacing.md),
              Text('오늘의 등급', style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xxs),
              Text(grade.label, style: theme.textTheme.headlineMedium?.copyWith(fontSize: 38)),
              const SizedBox(height: AppSpacing.xxs),
              SizedBox(width: 120, child: PencilRule(color: accent.withValues(alpha: 0.55))),
              const SizedBox(height: AppSpacing.xs),
              Text(
                grade.caption,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: AppPalette.graphite),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: <Widget>[
                    Text('브레인 점수', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 2),
                    Text(
                      _formatScore(score.brainScore),
                      style: theme.textTheme.headlineMedium?.copyWith(fontSize: 34),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        const SectionHeading(label: 'RECORD', title: '이번 판 기록'),
        const SizedBox(height: AppSpacing.sm),
        _StatGrid(
          tiles: <StatTile>[
            StatTile(label: '맞힌 문제', value: '${score.correctCount}'),
            StatTile(label: '푼 문제', value: '${score.attemptCount}'),
            StatTile(label: '정확도', value: '${(score.accuracyRate * 100).toStringAsFixed(0)}%'),
            StatTile(label: '분당 정답', value: score.correctPerMinute.toStringAsFixed(1)),
            StatTile(label: '최고 연속', value: '${score.comboMax}', accent: AppPalette.gold),
            StatTile(
              label: '회복한 시간',
              value: '+${(_controller.totalBonusMs / 1000).toStringAsFixed(1)}초',
              accent: AppPalette.mint,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        FilledButton(
          onPressed: _restart,
          style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
          child: const Text('한 판 더 하기'),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton(
          onPressed: _quitToReady,
          child: const Text('난이도 다시 고르기'),
        ),
      ],
    );
  }

  String _formatScore(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

// ----------------------------------------------------------------- 보조 위젯

class _TopBar extends StatelessWidget {
  const _TopBar({required this.online, this.trailing});

  final bool online;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final chip = trailing;
    return Row(
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppPalette.ink,
            borderRadius: BorderRadius.circular(9),
          ),
          // 유니코드 연필 문자는 기기 글꼴에 따라 빠질 수 있어 아이콘을 씁니다.
          child: const Icon(Icons.create_rounded, color: Colors.white, size: 16),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'BRAIN MATH',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppPalette.graphite),
        ),
        const Spacer(),
        if (chip != null) ...<Widget>[chip, const SizedBox(width: AppSpacing.xxs)],
        PaperChip(
          label: online ? '온라인' : '오프라인',
          color: online ? AppPalette.mint : AppPalette.faint,
          filled: online,
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = onTap != null ? AppPalette.graphite : AppPalette.faint;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnswerPreview extends StatelessWidget {
  const _AnswerPreview({required this.value, required this.accent});

  final String? value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = value;
    final hasValue = shown != null && shown.isNotEmpty;

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: hasValue ? accent.withValues(alpha: 0.12) : AppPalette.cardSunk,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: hasValue ? accent.withValues(alpha: 0.45) : AppPalette.lineSoft,
          width: 1.3,
        ),
      ),
      child: Row(
        children: <Widget>[
          Text('읽은 답', style: theme.textTheme.labelSmall),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              hasValue ? shown : '아직 없어요',
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                color: hasValue ? AppPalette.ink : AppPalette.faint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.tiles});

  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < tiles.length; start += 3) {
      final cells = <Widget>[];
      for (var column = 0; column < 3; column++) {
        if (column > 0) cells.add(const SizedBox(width: AppSpacing.xs));
        final index = start + column;
        cells.add(
          Expanded(
            child: index < tiles.length ? tiles[index] : const SizedBox.shrink(),
          ),
        );
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells),
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

/// 판이 시작되기 전 3-2-1 카운트다운.
class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({required this.value, required this.accent});

  final int value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned.fill(
      child: ColoredBox(
        color: AppPalette.paper.withValues(alpha: 0.94),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const PencilMascot(size: 96, mood: MascotMood.cheer),
              const SizedBox(height: AppSpacing.lg),
              TweenAnimationBuilder<double>(
                key: ValueKey<int>(value),
                tween: Tween<double>(begin: 0.6, end: 1),
                duration: AppDuration.base,
                curve: Curves.easeOutBack,
                builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 108,
                  height: 108,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppPalette.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 3),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(color: AppPalette.shadow, blurRadius: 24, offset: Offset(0, 10)),
                    ],
                  ),
                  child: Text(
                    '$value',
                    style: theme.textTheme.displayLarge?.copyWith(fontSize: 56),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('연필 준비!', style: theme.textTheme.titleLarge),
            ],
          ),
        ),
      ),
    );
  }
}
