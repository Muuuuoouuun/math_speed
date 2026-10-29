import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/paper_backdrop.dart';
import '../../../core/widgets/paper_card.dart';
import '../../ink/application/digital_ink_service.dart';
import '../../ink/domain/ink_models.dart';
import '../../ink/presentation/ink_canvas.dart';
import '../application/time_attack_session_controller.dart';
import '../data/leaderboard_repository.dart';
import '../data/time_attack_session_repository.dart';
import '../domain/game_mode.dart';
import '../domain/time_attack_ink_metrics.dart';
import 'leaderboard_panel.dart';
import 'ranked_status_panel.dart';

/// Four time-attack modes retain their own versioned engine and ranked records.
class TimeAttackPage extends StatefulWidget {
  const TimeAttackPage({
    this.controller,
    this.online = true,
    this.schoolId,
    this.regionCode,
    this.digitalInkService,
    this.leaderboardRepository,
    this.showLeaderboard = true,
    super.key,
  });

  final TimeAttackSessionController? controller;
  final bool online;
  final String? schoolId;
  final String? regionCode;
  final DigitalInkService? digitalInkService;
  final TimeAttackLeaderboardRepository? leaderboardRepository;
  final bool showLeaderboard;

  @override
  State<TimeAttackPage> createState() => _TimeAttackPageState();
}

class _TimeAttackPageState extends State<TimeAttackPage> {
  late final TimeAttackSessionController _controller;
  final _manualInput = TextEditingController();
  GameMode _selectedMode = GameMode.simpleCalculation;
  DigitalInkService? _digitalInkService;
  TimeAttackLeaderboardRepository? _leaderboardRepository;
  Timer? _recognitionDebounce;
  int _recognitionToken = 0;
  int _lastClearRevision = 0;
  String? _inkMessage;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        TimeAttackSessionController(
          rankedGateway: widget.online ? TimeAttackSessionRepository() : null,
        );
    _selectedMode = _controller.gameMode;
    _lastClearRevision = _controller.clearRevision;
    _digitalInkService = widget.digitalInkService;
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (_lastClearRevision != _controller.clearRevision) {
      _lastClearRevision = _controller.clearRevision;
      _recognitionToken++;
      _recognitionDebounce?.cancel();
      _manualInput.clear();
    }
    if (mounted) setState(() {});
  }

  void _start() {
    _inkMessage = null;
    if (widget.online && _controller.canPlayRanked) {
      unawaited(_controller.startRankedRound(mode: _selectedMode));
    } else {
      _controller.startRound(mode: _selectedMode);
    }
  }

  void _handleInkChanged(List<InkStrokeData> strokes, Size canvasSize) {
    _controller.updateInkMetrics(TimeAttackInkMetrics.fromStrokes(strokes));
    _recognitionDebounce?.cancel();
    final token = ++_recognitionToken;
    final revision = _controller.clearRevision;
    if (strokes.isEmpty) {
      _controller.updateRecognitionPreview('');
      return;
    }
    _recognitionDebounce = Timer(const Duration(milliseconds: 120), () async {
      try {
        final service = _digitalInkService ??= DigitalInkService();
        await service.ensureModelDownloaded();
        final preview = await service.recognize(
          strokes,
          writingAreaWidth: canvasSize.width,
          writingAreaHeight: canvasSize.height,
        );
        if (!mounted ||
            token != _recognitionToken ||
            revision != _controller.clearRevision ||
            !_controller.isRunning) {
          return;
        }
        _controller.updateRecognitionPreview(preview?.text ?? '');
        setState(() => _inkMessage = null);
      } catch (_) {
        if (!mounted || token != _recognitionToken) return;
        setState(() => _inkMessage = '손글씨 인식을 준비하지 못했어요. 아래에 답을 직접 입력해 주세요.');
      }
    });
  }

  void _submit() {
    if (_controller.submitCurrentProblem()) {
      unawaited(HapticFeedback.selectionClick());
    }
  }

  @override
  void dispose() {
    _recognitionToken++;
    _recognitionDebounce?.cancel();
    _controller.removeListener(_onControllerChanged);
    if (widget.controller == null) _controller.dispose();
    _manualInput.dispose();
    if (widget.digitalInkService == null) {
      unawaited(_digitalInkService?.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _controller.isRunning ||
        _controller.rankedStatus == RankedRoundStatus.preparing ||
        _controller.rankedStatus == RankedRoundStatus.submitting;
    final result = _controller.rankedResult;
    final showLeaderboard =
        widget.online && widget.showLeaderboard && result != null;
    if (showLeaderboard) {
      _leaderboardRepository ??=
          widget.leaderboardRepository ?? TimeAttackLeaderboardRepository();
    }
    return Scaffold(
      backgroundColor: AppPalette.paper,
      appBar: AppBar(title: const Text('시간제 랭크전')),
      body: PaperBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('정답을 맞히면 시간이 늘어나요',
                        style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      widget.online
                          ? '네 가지 모드에 도전해 보세요. 한 판은 최대 400문제 또는 9분이에요.'
                          : '오프라인 연습 중이에요. 기록은 랭킹에 저장되지 않아요.',
                    ),
                    const SizedBox(height: 20),
                    if (!busy) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: GameModeConfig.all
                            .map((config) => ChoiceChip(
                                  label: Text(config.label),
                                  selected: config.mode == _selectedMode,
                                  onSelected: (_) => setState(
                                      () => _selectedMode = config.mode),
                                ))
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        key: const Key('time-attack-start'),
                        onPressed: _start,
                        icon: const Icon(Icons.timer_outlined),
                        label: Text(widget.online ? '시간제 랭크 시작' : '시간제 연습 시작'),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_controller.isRunning) ...[
                      PaperCard(
                        accent: AppPalette.sky,
                        child: Column(
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 22,
                              runSpacing: 8,
                              children: [
                                Text('${_controller.formatTimeLeft()}초',
                                    style: theme.textTheme.headlineMedium),
                                Text(
                                    '${_controller.correctCount}개 정답 · ${_controller.currentCombo} 콤보'),
                              ],
                            ),
                            const SizedBox(height: 20),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${_controller.currentProblem?.prompt ?? ''} = ?',
                                style: theme.textTheme.headlineLarge,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_controller.lastAttemptCorrect != null)
                              Text(_controller.lastAttemptCorrect!
                                  ? '정답! +${(_controller.lastBonusAwardedMs / 1000).toStringAsFixed(1)}초'
                                  : '정답은 ${_controller.lastExpectedAnswer}였어요. 다음 문제에 도전해요.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 190,
                        child: InkCanvas(
                          clearRevision: _controller.clearRevision,
                          onInkChanged: _handleInkChanged,
                          accent: AppPalette.sky,
                        ),
                      ),
                      if (_inkMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_inkMessage!),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                              child: Text(
                                  '인식한 답: ${_controller.recognizedText.isEmpty ? '—' : _controller.recognizedText}')),
                          TextButton(
                              onPressed: _controller.clearInk,
                              child: const Text('지우기')),
                        ],
                      ),
                      TextField(
                        key: const Key('time-attack-answer'),
                        controller: _manualInput,
                        keyboardType:
                            const TextInputType.numberWithOptions(signed: true),
                        decoration: const InputDecoration(
                            labelText: '답 직접 입력', border: OutlineInputBorder()),
                        onChanged: (value) {
                          _recognitionToken++;
                          _controller.updateRecognitionPreview('');
                          _controller.updateManualFallback(value);
                        },
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        key: const Key('time-attack-submit'),
                        onPressed:
                            _controller.pendingAnswer.isEmpty ? null : _submit,
                        child: const Text('정답 확인'),
                      ),
                      const SizedBox(height: 16),
                    ],
                    RankedStatusPanel(
                      status: _controller.rankedStatus,
                      result: result,
                      error: _controller.rankedError,
                      canRetrySubmission: _controller.isGameOver &&
                          _controller.rankedSession != null,
                      onRetrySubmission: () =>
                          unawaited(_controller.retryRankedSubmission()),
                      onRestart: _start,
                    ),
                    if (_controller.isGameOver && !_controller.isRanked)
                      PaperCard(
                          child: Text(
                              '연습 완료! ${_controller.correctCount}개 정답 · ${_controller.scoreBreakdown.brainScore}점')),
                    if (showLeaderboard) ...[
                      const SizedBox(height: 20),
                      LeaderboardPanel(
                        repository: _leaderboardRepository!,
                        refreshToken: result.attemptId.hashCode,
                        highlightSchoolId: widget.schoolId,
                        highlightRegionCode: widget.regionCode,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
