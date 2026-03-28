import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../ink/domain/ink_models.dart';
import '../domain/brain_score.dart';
import '../domain/game_mode.dart';
import '../domain/math_problem.dart';
import '../domain/performance_grade.dart';
import '../domain/problem_generator.dart';

class GameSessionController extends ChangeNotifier {
  GameSessionController({
    ProblemGenerator? problemGenerator,
    BrainScoreCalculator? brainScoreCalculator,
    PerformanceGrader? performanceGrader,
  })  : _problemGenerator = problemGenerator ?? const ProblemGenerator(),
        _brainScoreCalculator = brainScoreCalculator ?? const BrainScoreCalculator(),
        _performanceGrader = performanceGrader ?? const PerformanceGrader();

  final ProblemGenerator _problemGenerator;
  final BrainScoreCalculator _brainScoreCalculator;
  final PerformanceGrader _performanceGrader;

  GameMode _gameMode = GameMode.simpleCalculation;
  int _seed = 0;
  int _clearRevision = 0;
  int _problemIndex = 0;
  int _timeLeftMs = 0;
  int _elapsedMs = 0;
  int _totalBonusMs = 0;
  int _currentCombo = 0;
  bool _isRunning = false;
  bool _hasFinished = false;
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
  bool get isGameOver => _hasFinished;
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
    _hasFinished = false;
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
    _currentProblemStartedAt = DateTime.now();
    _lastTickAt = DateTime.now();
    _clearRevision++;
    _startTicker();
    notifyListeners();
  }

  void setGameMode(GameMode mode) {
    if (_gameMode == mode && _attempts.isEmpty && _isRunning) {
      return;
    }
    startRound(mode: mode);
  }

  void restart() {
    startRound(mode: _gameMode);
  }

  void updateRecognitionPreview(String value) {
    _recognizedText = value.trim();
    notifyListeners();
  }

  void updateManualFallback(String value) {
    _manualFallback = value.trim();
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
    final normalized = rawInput.replaceAll(' ', '');
    if (normalized.isEmpty) {
      return false;
    }
    final expected = problem.answer.toString();
    final elapsedMsForProblem = DateTime.now()
        .difference(_currentProblemStartedAt ?? DateTime.now())
        .inMilliseconds
        .clamp(250, 99999) as int;
    final correct = normalized == expected;
    var awardedBonusMs = 0;

    _attempts.add(
      ProblemAttemptResult(
        correct: correct,
        elapsedMs: elapsedMsForProblem,
      ),
    );

    if (correct) {
      final nextTime = (_timeLeftMs + gameModeConfig.bonusTimeMs).clamp(0, gameModeConfig.maxTimeMs) as int;
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
    _currentProblemStartedAt = DateTime.now();
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
      final now = DateTime.now();
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
    _hasFinished = true;
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

