import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/paper_backdrop.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../core/widgets/pencil_doodles.dart';
import '../../ink/application/digital_ink_service.dart';
import '../../ink/domain/ink_models.dart';
import '../../ink/presentation/ink_canvas.dart';
import '../../profile/domain/profile_catalog.dart';
import '../application/ranked_run_controller.dart';
import '../data/leaderboard_repository.dart';
import '../data/ranked_session_repository.dart';
import '../domain/leaderboard_models.dart';
import 'widgets/game_pieces.dart';

/// 랭크전 한 판을 진행하는 화면.
///
/// 연습 모드와 달리 시간이 아니라 문제 수로 끝나고, 채점은 서버가 합니다.
class RankedRunPage extends StatefulWidget {
  const RankedRunPage({
    required this.level,
    this.sessionRepository,
    this.leaderboardRepository,
    this.digitalInkService,
    super.key,
  });

  final int level;

  /// 테스트에서 갈아 끼우기 위한 자리. 비워 두면 실제 구현을 씁니다.
  final RankedSessionRepository? sessionRepository;
  final LeaderboardRepository? leaderboardRepository;
  final DigitalInkService? digitalInkService;

  @override
  State<RankedRunPage> createState() => _RankedRunPageState();
}

class _RankedRunPageState extends State<RankedRunPage> {
  late final RankedRunController _controller;
  late final LeaderboardRepository _leaderboardRepository;
  DigitalInkService? _digitalInkService;

  final TextEditingController _fallbackController = TextEditingController();
  Timer? _recognitionDebounce;
  int _undoRevision = 0;

  String _leaderboardScope = 'school';
  Future<List<LeaderboardEntry>>? _leaderboardFuture;

  static const Color _accent = AppPalette.gold;

  @override
  void initState() {
    super.initState();
    _controller = RankedRunController(sessionRepository: widget.sessionRepository)
      ..addListener(_onPhaseChanged);
    _leaderboardRepository = widget.leaderboardRepository ?? LeaderboardRepository();
    _digitalInkService = widget.digitalInkService ?? DigitalInkService(languageCode: 'ko');
    unawaited(_controller.start(level: widget.level));
  }

  void _onPhaseChanged() {
    if (_controller.phase == RankedPhase.done && _leaderboardFuture == null) {
      _loadLeaderboard();
    }
    if (mounted) setState(() {});
  }

  void _loadLeaderboard() {
    _leaderboardFuture = _leaderboardRepository.loadTopEntries(scope: _leaderboardScope);
  }

  @override
  void dispose() {
    _recognitionDebounce?.cancel();
    _controller.removeListener(_onPhaseChanged);
    _controller.dispose();
    _fallbackController.dispose();
    unawaited(_digitalInkService?.dispose());
    super.dispose();
  }

  Future<void> _handleInkChanged(List<InkStrokeData> strokes, Size canvasSize) async {
    _controller.updateInk(strokes);

    _recognitionDebounce?.cancel();
    _recognitionDebounce = Timer(const Duration(milliseconds: 90), () async {
      final preview = await _digitalInkService?.recognize(
        strokes,
        writingAreaWidth: canvasSize.width,
        writingAreaHeight: canvasSize.height,
      );
      if (!mounted || preview == null) return;
      _controller.updateRecognitionPreview(preview.text);
    });
  }

  Future<void> _submit() async {
    final accepted = await _controller.submitCurrentProblem();
    if (!accepted) return;
    _fallbackController.clear();
    unawaited(HapticFeedback.selectionClick());
  }

  Future<void> _confirmGiveUp() async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppPalette.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: const Text('여기까지 제출할까요?'),
        content: const Text('남은 문제는 빈 답으로 기록돼요.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('더 풀기'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('제출하기'),
          ),
        ],
      ),
    );

    if (quit == true) {
      await _controller.giveUpAndSubmit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PaperBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
              child: AnimatedSwitcher(
                duration: AppDuration.base,
                child: _buildPhase(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhase(BuildContext context) {
    switch (_controller.phase) {
      case RankedPhase.idle:
      case RankedPhase.preparing:
        return const _RankedMessage(
          key: ValueKey<String>('preparing'),
          mood: MascotMood.happy,
          title: '문제를 받아오는 중',
          body: '이번 판의 문제를 서버에서 받아오고 있어요.',
          busy: true,
        );
      case RankedPhase.submitting:
        return const _RankedMessage(
          key: ValueKey<String>('submitting'),
          mood: MascotMood.happy,
          title: '채점 중',
          body: '푼 답을 서버로 보내 점수를 매기고 있어요.',
          busy: true,
        );
      case RankedPhase.failed:
        return _buildFailed(context);
      case RankedPhase.playing:
        return _buildPlaying(context);
      case RankedPhase.done:
        return _buildDone(context);
    }
  }

  // ------------------------------------------------------------------ 실패

  Widget _buildFailed(BuildContext context) {
    return _RankedMessage(
      key: const ValueKey<String>('failed'),
      mood: MascotMood.sleepy,
      title: '기록하지 못했어요',
      body: _controller.errorMessage,
      actions: <Widget>[
        FilledButton(
          onPressed: () => _controller.start(level: widget.level),
          style: FilledButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
          child: const Text('다시 시도하기'),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('연습으로 돌아가기'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- 플레이

  Widget _buildPlaying(BuildContext context) {
    final theme = Theme.of(context);
    final problem = _controller.currentProblem;
    final answered = _controller.answeredCount;
    final total = _controller.problemCount;
    final isLast = answered == total - 1;
    final timeLeft = _controller.timeLeft ?? Duration.zero;
    final answerPreview = _controller.recognizedText.isNotEmpty
        ? _controller.recognizedText
        : (_controller.manualFallback.isNotEmpty ? _controller.manualFallback : null);
    final hasInk = _controller.inkMetrics.strokeCount > 0;

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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // 작은 화면에서 칩과 버튼이 한 줄에 다 못 들어가면 칩만 접히게 둡니다.
            Expanded(
              child: Wrap(
                spacing: AppSpacing.xxs,
                runSpacing: AppSpacing.xxs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  PaperChip(label: '랭크전 레벨 ${_controller.level}', color: _accent, filled: true),
                  PaperChip(
                    label: _formatDuration(timeLeft),
                    color: timeLeft.inSeconds <= 30 ? AppPalette.blush : AppPalette.muted,
                    filled: timeLeft.inSeconds <= 30,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            TextButton.icon(
              onPressed: _confirmGiveUp,
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: const Text('그만'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // 진행률. 랭크전은 시간이 아니라 문제 수로 끝납니다.
        Row(
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: _controller.progress,
                  minHeight: 10,
                  backgroundColor: AppPalette.paperDeep,
                  valueColor: const AlwaysStoppedAnimation<Color>(_accent),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text('${answered + 1} / $total', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        PaperCard(
          accent: _accent,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            children: <Widget>[
              SectionLabel(text: '${answered + 1}번째 문제', color: _accent),
              const SizedBox(height: AppSpacing.md),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  problem?.prompt ?? '-',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayLarge,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        PaperCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const SectionLabel(text: '연습장', color: _accent),
                  const Spacer(),
                  _RankedTool(
                    icon: Icons.undo_rounded,
                    label: '되돌리기',
                    onTap: hasInk ? () => setState(() => _undoRevision++) : null,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  _RankedTool(
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
                  accent: _accent,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Container(
                      height: 58,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: answerPreview == null
                            ? AppPalette.cardSunk
                            : _accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: answerPreview == null
                              ? AppPalette.lineSoft
                              : _accent.withValues(alpha: 0.45),
                          width: 1.3,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Text('읽은 답', style: theme.textTheme.labelSmall),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              answerPreview ?? '아직 없어요',
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: answerPreview == null ? AppPalette.faint : AppPalette.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
          child: Text(isLast ? '제출하기' : '다음 문제'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '랭크전은 되돌아갈 수 없어요. 답을 내면 바로 다음 문제로 넘어가요.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ 결과

  Widget _buildDone(BuildContext context) {
    final theme = Theme.of(context);
    final result = _controller.result;
    final accuracy = ((result?.accuracyRate ?? 0) * 100).toStringAsFixed(0);

    return ListView(
      key: const ValueKey<String>('done'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.xl,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        PaperCard(
          accent: _accent,
          tapeLabel: '기록 완료',
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            children: <Widget>[
              const PencilMascot(size: 84, mood: MascotMood.cheer),
              const SizedBox(height: AppSpacing.md),
              Text('서버에 저장된 점수', style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${result?.brainScore ?? 0}',
                style: theme.textTheme.headlineMedium?.copyWith(fontSize: 44),
              ),
              const SizedBox(height: AppSpacing.xxs),
              const SizedBox(width: 120, child: PencilRule(color: Color(0x8CD3A03F))),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '레벨 ${_controller.level} · 학교와 지역 랭킹에 함께 반영돼요.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: StatTile(label: '맞힌 문제', value: '${result?.correctCount ?? 0}'),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: StatTile(label: '정확도', value: '$accuracy%')),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: StatTile(
                  label: '최고 연속',
                  value: '${result?.comboMax ?? 0}',
                  accent: AppPalette.gold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        const SectionHeading(label: 'RANKING', title: '지금 순위'),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          children: <Widget>[
            for (final scope in const <List<String>>[
              <String>['school', '학교'],
              <String>['region', '지역'],
              <String>['global', '전체'],
            ])
              GestureDetector(
                onTap: () => setState(() {
                  _leaderboardScope = scope[0];
                  _loadLeaderboard();
                }),
                child: PaperChip(
                  label: scope[1],
                  color: _accent,
                  filled: _leaderboardScope == scope[0],
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _LeaderboardPanel(
          future: _leaderboardFuture,
          scope: _leaderboardScope,
        ),
        const SizedBox(height: AppSpacing.xl),

        OutlinedButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('연습으로 돌아가기'),
        ),
      ],
    );
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')} 남음';
  }
}

class _RankedMessage extends StatelessWidget {
  const _RankedMessage({
    required this.mood,
    required this.title,
    required this.body,
    this.busy = false,
    this.actions,
    super.key,
  });

  final MascotMood mood;
  final String title;
  final String body;
  final bool busy;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PencilMascot(size: 88, mood: mood, bobbing: busy),
              const SizedBox(height: AppSpacing.lg),
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(body, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              if (busy) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                const SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    backgroundColor: AppPalette.paperDeep,
                    valueColor: AlwaysStoppedAnimation<Color>(AppPalette.gold),
                  ),
                ),
              ],
              if (actions != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xl),
                ...actions!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardPanel extends StatelessWidget {
  const _LeaderboardPanel({required this.future, required this.scope});

  final Future<List<LeaderboardEntry>>? future;
  final String scope;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PaperCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: FutureBuilder<List<LeaderboardEntry>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text('순위를 불러오는 중이에요', style: theme.textTheme.bodyMedium),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text('순위를 불러오지 못했어요', style: theme.textTheme.bodyMedium),
            );
          }

          final entries = snapshot.data ?? const <LeaderboardEntry>[];
          if (entries.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                '아직 집계된 순위가 없어요. 조금 뒤에 다시 확인해 주세요.',
                style: theme.textTheme.bodyMedium,
              ),
            );
          }

          return Column(
            children: <Widget>[
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 28,
                        child: Text('${entry.rank}', style: theme.textTheme.titleMedium),
                      ),
                      Expanded(
                        child: Text(
                          _labelFor(scope, entry.entityId),
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        entry.score.toStringAsFixed(0),
                        style: theme.textTheme.titleMedium?.copyWith(color: AppPalette.ink),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static String _labelFor(String scope, String entityId) {
    switch (scope) {
      case 'school':
        return schoolNameFor(entityId);
      case 'region':
        return regionNameFor(entityId);
      default:
        return '전체';
    }
  }
}

class _RankedTool extends StatelessWidget {
  const _RankedTool({
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
    return Material(
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
    );
  }
}
