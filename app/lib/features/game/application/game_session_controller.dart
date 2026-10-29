import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../ink/domain/ink_models.dart';
import '../domain/answer_normalizer.dart';
import '../domain/brain_score.dart';
import '../domain/game_mode.dart';
import '../domain/math_problem.dart';
import '../domain/performance_grade.dart';
import '../domain/problem_generator.dart';

/// 한 판의 진행 단계.
///
/// 시작 화면(ready) → 플레이(playing) → 결과(finished) 순서로 넘어갑니다.
enum RoundPhase { ready, playing, finished }

class GameSessionController extends ChangeNotifier {
  GameSessionController({
    ProblemGenerator? problemGenerator,
    BrainScoreCalculator? brainScoreCalculator,
    PerformanceGrader? performanceGrader,
    DateTime Function()? clock,
  })  : _problemGenerator = problemGenerator ?? const ProblemGenerator(),
        _brainScoreCalculator = brainScoreCalculator ?? const BrainScoreCalculator(),
        _performanceGrader = performanceGrader ?? const PerformanceGrader(),
        _now = clock ?? DateTime.now {
    // 시작 화면에서도 게이지가 가득 찬 상태로 보이도록 초기 시간을 채워 둡니다.
    _timeLeftMs = GameModeConfig.fromMode(_gameMode).initialTimeMs;
  }

  final ProblemGenerator _problemGenerator;
  final BrainScoreCalculator _brainScoreCalculator;
  final PerformanceGrader _performanceGrader;

  /// 남은 시간은 프레임이 아니라 실제 시계로 재야 정확합니다.
  /// 테스트에서는 가짜 시계를 넣어 시간을 마음대로 흘려보냅니다.
  final DateTime Function() _now;

  GameMode _gameMode = GameMode.simpleCalculation;
  int _seed = 0;
  int _clearRevision = 0;
  int _problemIndex = 0;
  int _timeLeftMs = 0;
  int _elapsedMs = 0;
  int _totalBonusMs = 0;
  int _currentCombo = 0;
  bool _isRunning = false;
  RoundPhase _phase = RoundPhase.ready;
  MathProblem? _currentProblem;
  final List<ProblemAttemptResult> _attempts = <ProblemAttemptResult>[];
  String _recognizedText = '';
  String _manualFallback = '';
  bool? _lastAttemptCorrect;
  int _lastBonusAwardedMs = 0;
  String _lastSubmittedAnswer = '';
  int? _lastExpectedAnswer;
  DateTime? _currentProblemStartedAt;
  DateTime? _lastTickAt;
  Timer? _roundTicker;
  InkMetrics _currentInkMetrics = InkMetrics.empty;

  GameMode get gameMode => _gameMode;
  GameModeConfig get gameModeConfig => GameModeConfig.fromMode(_gameMode);
  int get seed => _seed;
  int get clearRevision => _clearRevision;
  int get timeLeftMs => _timeLeftMs;
  int get elapsedMs => _elapsedMs;
  int get totalBonusMs => _totalBonusMs;
  int get currentCombo => _currentCombo;
  bool get isRunning => _isRunning;
  RoundPhase get phase => _phase;
  bool get isReady => _phase == RoundPhase.ready;
  bool get isGameOver => _phase == RoundPhase.finished;

  /// 남은 시간 비율(0~1). 게이지와 강조색 계산에 씁니다.
  double get timeRatio =>
      (_timeLeftMs / gameModeConfig.maxTimeMs).clamp(0.0, 1.0).toDouble();
  String get recognizedText => _recognizedText;
  String get manualFallback => _manualFallback;
  InkMetrics get currentInkMetrics => _currentInkMetrics;
  MathProblem? get currentProblem => _currentProblem;
  bool? get lastAttemptCorrect => _lastAttemptCorrect;
  int get lastBonusAwardedMs => _lastBonusAwardedMs;
  String get lastSubmittedAnswer => _lastSubmittedAnswer;
  int? get lastExpectedAnswer => _lastExpectedAnswer;
  List<ProblemAttemptResult> get attempts => List.unmodifiable(_attempts);

  int get attemptCount => _attempts.length;
  BrainScoreBreakdown get scoreBreakdown => _brainScoreCalculator.calculate(
        mode: _gameMode,
        attempts: _attempts,
      );
  int get correctCount => scoreBreakdown.correctCount;
  double get accuracyRate => scoreBreakdown.accuracyRate;
  PerformanceGrade get performanceGrade => _performanceGrader.grade(
        mode: _gameMode,
        correctCount: correctCount,
        attemptCount: attemptCount,
        elapsedMs: _elapsedMs == 0 ? 1 : _elapsedMs,
      );

  void startRound({
    GameMode? mode,
    int? seed,
  }) {
    _roundTicker?.cancel();
    _gameMode = mode ?? _gameMode;
    _seed = seed ?? Random().nextInt(0x7FFFFFFF);
    _problemIndex = 0;
    _timeLeftMs = gameModeConfig.initialTimeMs;
    _elapsedMs = 0;
    _totalBonusMs = 0;
    _currentCombo = 0;
    _isRunning = true;
    _phase = RoundPhase.playing;
    _attempts.clear();
    _recognizedText = '';
    _manualFallback = '';
    _lastAttemptCorrect = null;
    _lastBonusAwardedMs = 0;
    _lastSubmittedAnswer = '';
    _lastExpectedAnswer = null;
    _currentInkMetrics = InkMetrics.empty;
    _currentProblem = _problemGenerator.generateProblem(
      seed: _seed,
      mode: _gameMode,
      index: _problemIndex,
    );
    _currentProblemStartedAt = _now();
    _lastTickAt = _now();
    _clearRevision++;
    _startTicker();
    notifyListeners();
  }

  void setGameMode(GameMode mode) {
    // 시작 화면에서는 판을 새로 열지 않고 선택만 바꿉니다.
    if (_phase == RoundPhase.ready) {
      if (_gameMode == mode) return;
      _gameMode = mode;
      _timeLeftMs = gameModeConfig.initialTimeMs;
      notifyListeners();
      return;
    }
    if (_gameMode == mode && _attempts.isEmpty && _isRunning) {
      return;
    }
    startRound(mode: mode);
  }

  void restart() {
    startRound(mode: _gameMode);
  }

  /// 판을 접고 시작 화면으로 돌아갑니다.
  void returnToReady() {
    _roundTicker?.cancel();
    _roundTicker = null;
    _isRunning = false;
    _phase = RoundPhase.ready;
    _problemIndex = 0;
    _timeLeftMs = gameModeConfig.initialTimeMs;
    _elapsedMs = 0;
    _totalBonusMs = 0;
    _currentCombo = 0;
    _attempts.clear();
    _currentProblem = null;
    _recognizedText = '';
    _manualFallback = '';
    _lastAttemptCorrect = null;
    _lastBonusAwardedMs = 0;
    _lastSubmittedAnswer = '';
    _lastExpectedAnswer = null;
    _currentInkMetrics = InkMetrics.empty;
    _clearRevision++;
    notifyListeners();
  }

  void updateRecognitionPreview(String value) {
    _recognizedText = value.trim();
    notifyListeners();
  }

  void updateManualFallback(String value) {
    _manualFallback = value.trim();
    notifyListeners();
  }

  /// 손글씨만 지웁니다. 문제와 남은 시간은 그대로 둡니다.
  void clearInk() {
    _clearRevision++;
    _recognizedText = '';
    _currentInkMetrics = InkMetrics.empty;
    notifyListeners();
  }

  void updateInkMetrics(InkMetrics metrics) {
    _currentInkMetrics = metrics;
    notifyListeners();
  }

  bool submitCurrentProblem() {
    final problem = _currentProblem;
    if (!_isRunning || problem == null) {
      return false;
    }

    final rawInput = _recognizedText.isEmpty ? _manualFallback : _recognizedText;
    // 서버 채점과 같은 규칙으로 정리합니다. 인식기가 흘린 쉼표나 마침표 때문에
    // 맞게 쓴 답이 오답이 되는 일을 막습니다.
    final normalized = normalizeMathAnswer(rawInput);
    if (normalized.isEmpty) {
      return false;
    }
    final expected = problem.answer.toString();
    final elapsedMsForProblem = _now()
        .difference(_currentProblemStartedAt ?? _now())
        .inMilliseconds
        .clamp(250, 99999);
    final correct = normalized == expected;
    var awardedBonusMs = 0;

    _attempts.add(
      ProblemAttemptResult(
        correct: correct,
        elapsedMs: elapsedMsForProblem,
      ),
    );

    if (correct) {
      final nextTime = (_timeLeftMs + gameModeConfig.bonusTimeMs).clamp(0, gameModeConfig.maxTimeMs);
      awardedBonusMs = nextTime - _timeLeftMs;
      _totalBonusMs += awardedBonusMs;
      _timeLeftMs = nextTime;
      _currentCombo += 1;
    } else {
      _currentCombo = 0;
    }

    _problemIndex += 1;
    _lastAttemptCorrect = correct;
    _lastBonusAwardedMs = awardedBonusMs;
    _lastSubmittedAnswer = normalized;
    _lastExpectedAnswer = problem.answer;
    _recognizedText = '';
    _manualFallback = '';
    _currentInkMetrics = InkMetrics.empty;
    _currentProblemStartedAt = _now();
    _currentProblem = _problemGenerator.generateProblem(
      seed: _seed,
      mode: _gameMode,
      index: _problemIndex,
    );
    _clearRevision++;
    notifyListeners();
    return true;
  }

  String formatTimeLeft() {
    final safeMs = _timeLeftMs < 0 ? 0 : _timeLeftMs;
    final seconds = safeMs ~/ 1000;
    final hundredths = (safeMs % 1000) ~/ 100;
    return '$seconds.$hundredths';
  }

  void _startTicker() {
    _roundTicker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!_isRunning) return;
      final now = _now();
      final deltaMs = now.difference(_lastTickAt ?? now).inMilliseconds;
      _lastTickAt = now;
      _elapsedMs += deltaMs;
      _timeLeftMs -= deltaMs;
      if (_timeLeftMs <= 0) {
        _timeLeftMs = 0;
        _finishRound();
      }
      notifyListeners();
    });
  }

  void _finishRound() {
    _roundTicker?.cancel();
    _roundTicker = null;
    _isRunning = false;
    _phase = RoundPhase.finished;
    _currentProblem = null;
    _recognizedText = '';
    _manualFallback = '';
    _currentInkMetrics = InkMetrics.empty;
    _clearRevision++;
  }

  @override
  void dispose() {
    _roundTicker?.cancel();
    super.dispose();
  }
}

