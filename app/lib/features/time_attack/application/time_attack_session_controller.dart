import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/time_attack_ink_metrics.dart';
import '../domain/answer_normalizer.dart';
import '../domain/brain_score.dart';
import '../domain/game_mode.dart';
import '../domain/math_problem.dart';
import '../domain/performance_grade.dart';
import '../domain/problem_generator.dart';
import '../domain/ranked_models.dart';

/// 랭크 세션 발급/제출을 담당하는 서버 경계입니다. 오프라인이면 컨트롤러에 넘기지 않습니다.
abstract class RankedGateway {
  Future<RankedSessionEnvelope> createRankedSession({required GameMode mode});

  Future<RankedSubmissionResult> submitRankedSession({
    required String sessionId,
    required List<RankedSubmissionAnswer> answers,
  });
}

enum RankedRoundStatus {
  idle,
  preparing,
  playing,
  submitting,
  submitted,
  failed,
}

class TimeAttackSessionController extends ChangeNotifier {
  TimeAttackSessionController({
    ProblemGenerator? problemGenerator,
    BrainScoreCalculator? brainScoreCalculator,
    PerformanceGrader? performanceGrader,
    RankedGateway? rankedGateway,
    DateTime Function()? clock,
  })  : _problemGenerator = problemGenerator ?? const ProblemGenerator(),
        _brainScoreCalculator =
            brainScoreCalculator ?? const BrainScoreCalculator(),
        _performanceGrader = performanceGrader ?? const PerformanceGrader(),
        _rankedGateway = rankedGateway,
        _clock = clock ?? DateTime.now;

  static const int minProblemElapsedMs = 250;
  static const int maxProblemElapsedMs = 99999;
  static const Duration submissionMargin = Duration(seconds: 2);

  final ProblemGenerator _problemGenerator;
  final BrainScoreCalculator _brainScoreCalculator;
  final PerformanceGrader _performanceGrader;
  final RankedGateway? _rankedGateway;
  final DateTime Function() _clock;

  GameMode _gameMode = GameMode.simpleCalculation;
  SessionMode _sessionMode = SessionMode.practice;
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
  final List<ProblemSubmissionRecord> _records = <ProblemSubmissionRecord>[];
  String _recognizedText = '';
  String _manualFallback = '';
  bool? _lastAttemptCorrect;
  int _lastBonusAwardedMs = 0;
  String _lastSubmittedAnswer = '';
  int? _lastExpectedAnswer;
  DateTime? _currentProblemStartedAt;
  DateTime? _lastTickAt;
  DateTime? _roundStartedAt;
  Timer? _roundTicker;
  TimeAttackInkMetrics _currentInkMetrics = TimeAttackInkMetrics.empty;
  BrainScoreBreakdown? _cachedScore;

  RankedRoundStatus _rankedStatus = RankedRoundStatus.idle;
  RankedSessionEnvelope? _rankedSession;
  RankedSubmissionResult? _rankedResult;
  String? _rankedError;
  int _rankedRequestToken = 0;
  bool _disposed = false;

  GameMode get gameMode => _gameMode;
  GameModeConfig get gameModeConfig => GameModeConfig.fromMode(_gameMode);
  SessionMode get sessionMode => _sessionMode;
  bool get isRanked => _sessionMode == SessionMode.ranked;
  bool get canPlayRanked => _rankedGateway != null;
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
  TimeAttackInkMetrics get currentInkMetrics => _currentInkMetrics;
  MathProblem? get currentProblem => _currentProblem;
  bool? get lastAttemptCorrect => _lastAttemptCorrect;
  int get lastBonusAwardedMs => _lastBonusAwardedMs;
  String get lastSubmittedAnswer => _lastSubmittedAnswer;
  int? get lastExpectedAnswer => _lastExpectedAnswer;
  List<ProblemAttemptResult> get attempts => List.unmodifiable(_attempts);
  List<ProblemSubmissionRecord> get records => List.unmodifiable(_records);

  RankedRoundStatus get rankedStatus => _rankedStatus;
  RankedSessionEnvelope? get rankedSession => _rankedSession;
  RankedSubmissionResult? get rankedResult => _rankedResult;
  String? get rankedError => _rankedError;

  /// 현재 입력으로 제출하면 채점될 답입니다. 손글씨 인식값이 우선이고, 없으면 직접 입력값을 씁니다.
  String get pendingAnswer => normalizeAnswer(
      _recognizedText.isEmpty ? _manualFallback : _recognizedText);

  int get attemptCount => _attempts.length;
  BrainScoreBreakdown get scoreBreakdown =>
      _cachedScore ??= _brainScoreCalculator.calculate(
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

  /// 연습 라운드를 시작합니다. 진행 중이던 랭크 세션은 제출하지 않고 버립니다.
  void startRound({
    GameMode? mode,
    int? seed,
  }) {
    _rankedRequestToken++;
    _sessionMode = SessionMode.practice;
    _resetRanked();
    _beginRound(mode: mode, seed: seed);
    notifyListeners();
  }

  /// 서버에서 seed를 받아 랭크 라운드를 시작합니다. 라운드가 끝나면 자동으로 제출합니다.
  Future<void> startRankedRound({GameMode? mode}) async {
    final gateway = _rankedGateway;
    if (gateway == null) {
      return;
    }

    final token = ++_rankedRequestToken;
    _stopTicker();
    _sessionMode = SessionMode.ranked;
    _gameMode = mode ?? _gameMode;
    _resetRanked();
    _rankedStatus = RankedRoundStatus.preparing;
    _clearRound();
    notifyListeners();

    try {
      final session = await gateway.createRankedSession(mode: _gameMode);
      if (_disposed || token != _rankedRequestToken) return;
      if (session.balanceVersion != 'game_balance_v2' ||
          session.maxAnswers < 1 ||
          session.maxAnswers > 400 ||
          session.maxRoundDurationMs < 1 ||
          session.maxRoundDurationMs > 540000 ||
          !session.expiresAt.isAfter(_clock().add(submissionMargin))) {
        throw const FormatException(
            'Unsupported or expired time attack session.');
      }
      _rankedSession = session;
      _rankedStatus = RankedRoundStatus.playing;
      _beginRound(mode: session.mode, seed: session.seed);
    } catch (error) {
      if (_disposed || token != _rankedRequestToken) return;
      _rankedStatus = RankedRoundStatus.failed;
      _rankedError = describeRankedError(error);
    }
    notifyListeners();
  }

  void setSessionMode(SessionMode mode) {
    if (mode == _sessionMode) return;
    if (mode == SessionMode.ranked) {
      unawaited(startRankedRound());
    } else {
      startRound();
    }
  }

  void setGameMode(GameMode mode) {
    if (_gameMode == mode &&
        _attempts.isEmpty &&
        (_isRunning || _rankedStatus == RankedRoundStatus.preparing)) {
      return;
    }
    if (isRanked) {
      unawaited(startRankedRound(mode: mode));
    } else {
      startRound(mode: mode);
    }
  }

  void restart() {
    if (isRanked) {
      unawaited(startRankedRound());
    } else {
      startRound();
    }
  }

  /// 제출에 실패한 랭크 라운드를 같은 답안으로 다시 제출합니다.
  Future<void> retryRankedSubmission() async {
    if (_rankedStatus != RankedRoundStatus.failed ||
        _rankedSession == null ||
        !_hasFinished) {
      return;
    }
    await _submitRanked();
  }

  void updateRecognitionPreview(String value) {
    _recognizedText = value.trim();
    notifyListeners();
  }

  void updateManualFallback(String value) {
    _manualFallback = value.trim();
    notifyListeners();
  }

  void updateInkMetrics(TimeAttackInkMetrics metrics) {
    _currentInkMetrics = metrics;
    notifyListeners();
  }

  /// 현재 문제의 손글씨를 지웁니다. 문제와 경과 시간은 그대로 유지됩니다.
  void clearInk() {
    if (!_isRunning) return;
    _recognizedText = '';
    _currentInkMetrics = TimeAttackInkMetrics.empty;
    _clearRevision++;
    notifyListeners();
  }

  bool submitCurrentProblem() {
    // Drain real elapsed time before applying a bonus. A delayed timer callback
    // must not allow a late answer to revive an already finished round.
    tick();
    final problem = _currentProblem;
    if (!_isRunning || problem == null) {
      return false;
    }

    final normalized = pendingAnswer;
    if (normalized.isEmpty) {
      return false;
    }
    final now = _clock();
    final expected = problem.answer.toString();
    final elapsedMsForProblem = now
        .difference(_currentProblemStartedAt ?? now)
        .inMilliseconds
        .clamp(minProblemElapsedMs, maxProblemElapsedMs);
    final correct = normalized == expected;
    var awardedBonusMs = 0;

    _attempts.add(
      ProblemAttemptResult(
        correct: correct,
        elapsedMs: elapsedMsForProblem,
      ),
    );
    _records.add(
      ProblemSubmissionRecord(
        problemIndex: problem.index,
        submittedText: normalized,
        expectedAnswer: expected,
        elapsedMs: elapsedMsForProblem,
        strokeCount: _currentInkMetrics.strokeCount,
        pointCount: _currentInkMetrics.pointCount,
        inkHash: _currentInkMetrics.inkHash,
        correct: correct,
      ),
    );
    _cachedScore = null;

    if (correct) {
      final nextTime = (_timeLeftMs + gameModeConfig.bonusTimeMs)
          .clamp(0, gameModeConfig.maxTimeMs);
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
    _currentInkMetrics = TimeAttackInkMetrics.empty;
    _currentProblemStartedAt = now;
    _currentProblem = _problemGenerator.generateProblem(
      seed: _seed,
      mode: _gameMode,
      index: _problemIndex,
    );
    _clearRevision++;
    if (isRanked && _records.length >= _rankedSession!.maxAnswers) {
      _finishRound();
    }
    notifyListeners();
    return true;
  }

  String formatTimeLeft() {
    final safeMs = _timeLeftMs < 0 ? 0 : _timeLeftMs;
    final seconds = safeMs ~/ 1000;
    final tenths = (safeMs % 1000) ~/ 100;
    return '$seconds.$tenths';
  }

  /// 타이머 한 틱을 처리합니다. 테스트에서는 주입한 clock과 함께 직접 호출합니다.
  @visibleForTesting
  void tick() {
    if (!_isRunning) return;
    final now = _clock();
    final deltaMs = max(0, now.difference(_lastTickAt ?? now).inMilliseconds);
    _lastTickAt = now;
    _elapsedMs += deltaMs;
    _timeLeftMs -= deltaMs;
    final session = _rankedSession;
    final durationLimitReached = isRanked &&
        session != null &&
        (now.difference(_roundStartedAt ?? now).inMilliseconds >=
                session.maxRoundDurationMs ||
            !now.isBefore(session.expiresAt.subtract(submissionMargin)));
    if (_timeLeftMs <= 0 || durationLimitReached) {
      _timeLeftMs = 0;
      _finishRound();
    }
    notifyListeners();
  }

  void _beginRound({
    GameMode? mode,
    int? seed,
  }) {
    _stopTicker();
    _gameMode = mode ?? _gameMode;
    _seed = seed ?? Random().nextInt(0x7FFFFFFF);
    _clearRound();
    _timeLeftMs = gameModeConfig.initialTimeMs;
    _isRunning = true;
    _currentProblem = _problemGenerator.generateProblem(
      seed: _seed,
      mode: _gameMode,
      index: _problemIndex,
    );
    final now = _clock();
    _roundStartedAt = now;
    _currentProblemStartedAt = now;
    _lastTickAt = now;
    _roundTicker =
        Timer.periodic(const Duration(milliseconds: 100), (_) => tick());
  }

  void _clearRound() {
    _problemIndex = 0;
    _timeLeftMs = 0;
    _elapsedMs = 0;
    _totalBonusMs = 0;
    _currentCombo = 0;
    _isRunning = false;
    _hasFinished = false;
    _currentProblem = null;
    _attempts.clear();
    _records.clear();
    _cachedScore = null;
    _recognizedText = '';
    _manualFallback = '';
    _lastAttemptCorrect = null;
    _lastBonusAwardedMs = 0;
    _lastSubmittedAnswer = '';
    _lastExpectedAnswer = null;
    _currentInkMetrics = TimeAttackInkMetrics.empty;
    _clearRevision++;
  }

  void _resetRanked() {
    _rankedStatus = RankedRoundStatus.idle;
    _rankedSession = null;
    _rankedResult = null;
    _rankedError = null;
  }

  void _finishRound() {
    _stopTicker();
    _isRunning = false;
    _hasFinished = true;
    _currentProblem = null;
    _recognizedText = '';
    _manualFallback = '';
    _currentInkMetrics = TimeAttackInkMetrics.empty;
    _clearRevision++;

    if (isRanked && _rankedSession != null) {
      unawaited(_submitRanked());
    }
  }

  Future<void> _submitRanked() async {
    final gateway = _rankedGateway;
    final session = _rankedSession;
    if (gateway == null || session == null) return;

    final token = _rankedRequestToken;
    _rankedStatus = RankedRoundStatus.submitting;
    _rankedError = null;
    notifyListeners();

    try {
      final result = await gateway.submitRankedSession(
        sessionId: session.sessionId,
        answers: _records
            .map((record) => record.toRankedAnswer())
            .toList(growable: false),
      );
      if (_disposed || token != _rankedRequestToken) return;
      _rankedResult = result;
      _rankedStatus = RankedRoundStatus.submitted;
    } catch (error) {
      if (_disposed || token != _rankedRequestToken) return;
      _rankedStatus = RankedRoundStatus.failed;
      _rankedError = describeRankedError(error);
    }
    notifyListeners();
  }

  void _stopTicker() {
    _roundTicker?.cancel();
    _roundTicker = null;
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTicker();
    super.dispose();
  }
}

/// 서버 오류를 사용자에게 보여줄 짧은 문장으로 바꿉니다.
String describeRankedError(Object error) {
  final code = _errorCode(error);
  switch (code) {
    case 'failed-precondition':
      return '프로필(학교·지역)을 확인한 뒤 다시 시도해 주세요.';
    case 'deadline-exceeded':
      return '세션 시간이 지나 기록을 저장하지 못했어요.';
    case 'unavailable':
    case 'internal':
      return '서버에 연결하지 못했어요. 네트워크를 확인해 주세요.';
    case 'unauthenticated':
      return '로그인 정보가 만료됐어요. 앱을 다시 열어 주세요.';
    default:
      return '랭크 기록을 처리하지 못했어요. 잠시 후 다시 시도해 주세요.';
  }
}

String? _errorCode(Object error) {
  try {
    final dynamic dynamicError = error;
    final code = dynamicError.code;
    return code is String ? code : null;
  } catch (_) {
    return null;
  }
}
