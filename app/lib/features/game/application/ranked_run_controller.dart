import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../ink/domain/ink_hash.dart';
import '../../ink/domain/ink_models.dart';
import '../data/ranked_session_repository.dart';
import '../domain/answer_normalizer.dart';
import '../domain/math_problem.dart';
import '../domain/ranked_models.dart';
import '../domain/ranked_problem_generator.dart';

/// 랭크전 한 판의 진행 상태.
enum RankedPhase {
  /// 아직 시작하지 않음.
  idle,

  /// 서버에서 세션(시드/문제 수)을 받아오는 중.
  preparing,

  /// 문제를 푸는 중.
  playing,

  /// 답을 서버로 보내 채점받는 중.
  submitting,

  /// 채점 결과를 받음.
  done,

  /// 실패. [errorMessage]에 이유가 들어 있습니다.
  failed,
}

/// 랭크전은 연습 모드와 규칙이 다릅니다.
///
/// - 시간 제한이 아니라 정해진 문제 수를 끝까지 풉니다.
/// - 문제는 서버가 준 시드로 만들고, 채점도 서버가 같은 시드로 다시 만들어서 합니다.
/// - 세션에는 만료 시각이 있어서, 늦으면 제출이 거절됩니다. 그래서 만료 직전에
///   남은 문제를 빈 답으로 채워 자동 제출합니다.
class RankedRunController extends ChangeNotifier {
  RankedRunController({
    RankedSessionRepository? sessionRepository,
    RankedProblemGenerator generator = const RankedProblemGenerator(),
    DateTime Function()? clock,
  })  : _sessionRepository = sessionRepository ?? RankedSessionRepository(),
        _generator = generator,
        _now = clock ?? DateTime.now;

  final RankedSessionRepository _sessionRepository;
  final RankedProblemGenerator _generator;
  final DateTime Function() _now;

  /// 만료 몇 초 전에 자동 제출할지.
  static const Duration autoSubmitMargin = Duration(seconds: 12);

  RankedPhase _phase = RankedPhase.idle;
  String _errorMessage = '';
  RankedSessionEnvelope? _envelope;
  List<MathProblem> _problems = const <MathProblem>[];
  final List<RankedSubmissionAnswer> _answers = <RankedSubmissionAnswer>[];
  RankedSubmissionResult? _result;

  int _currentIndex = 0;
  int _clearRevision = 0;
  bool? _lastAnswerCorrect;
  int? _lastExpectedAnswer;
  String _lastSubmittedAnswer = '';
  int _localCorrectCount = 0;
  int _localCombo = 0;
  String _recognizedText = '';
  String _manualFallback = '';
  InkMetrics _inkMetrics = InkMetrics.empty;
  List<InkStrokeData> _strokes = const <InkStrokeData>[];
  DateTime? _problemStartedAt;
  Timer? _expiryTicker;

  RankedPhase get phase => _phase;
  String get errorMessage => _errorMessage;
  int get level => _envelope?.level ?? 0;
  int get problemCount => _envelope?.problemCount ?? 0;
  int get currentIndex => _currentIndex;
  int get clearRevision => _clearRevision;
  String get recognizedText => _recognizedText;
  String get manualFallback => _manualFallback;
  InkMetrics get inkMetrics => _inkMetrics;
  RankedSubmissionResult? get result => _result;
  MathProblem? get currentProblem =>
      _currentIndex < _problems.length ? _problems[_currentIndex] : null;

  /// 0~1 진행률.
  double get progress => problemCount == 0 ? 0 : _currentIndex / problemCount;

  /// 세션이 만료되기까지 남은 시간. 세션이 없으면 null.
  Duration? get timeLeft {
    final expiresAt = _envelope?.expiresAt;
    if (expiresAt == null) return null;
    final left = expiresAt.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  /// 지금까지 답을 낸 문제 수.
  int get answeredCount => _answers.length;

  // 아래 세 값은 화면에 바로 보여 주기 위한 것입니다. 최종 점수는 어디까지나
  // 서버가 매기지만, 문제와 정규화 규칙이 서버와 똑같기 때문에 판정도 같습니다.
  bool? get lastAnswerCorrect => _lastAnswerCorrect;
  int? get lastExpectedAnswer => _lastExpectedAnswer;
  String get lastSubmittedAnswer => _lastSubmittedAnswer;
  int get localCorrectCount => _localCorrectCount;
  int get localCombo => _localCombo;

  Future<void> start({required int level}) async {
    _expiryTicker?.cancel();
    _phase = RankedPhase.preparing;
    _errorMessage = '';
    _envelope = null;
    _problems = const <MathProblem>[];
    _answers.clear();
    _result = null;
    _currentIndex = 0;
    _clearRevision++;
    _lastAnswerCorrect = null;
    _lastExpectedAnswer = null;
    _lastSubmittedAnswer = '';
    _localCorrectCount = 0;
    _localCombo = 0;
    _resetInput();
    notifyListeners();

    try {
      final envelope = await _sessionRepository.createRankedSession(level: level);
      _envelope = envelope;
      // 서버가 준 seed/level/problemCount를 그대로 써야 채점이 맞습니다.
      _problems = _generator.generateSession(
        seed: envelope.seed,
        level: envelope.level,
        count: envelope.problemCount,
      );
      _phase = RankedPhase.playing;
      _problemStartedAt = _now();
      _startExpiryTicker();
    } catch (error) {
      _fail(error);
    }
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

  void updateInk(List<InkStrokeData> strokes) {
    _strokes = strokes;
    _inkMetrics = InkMetrics(
      strokeCount: strokes.length,
      pointCount: strokes.fold<int>(0, (sum, stroke) => sum + stroke.points.length),
    );
    notifyListeners();
  }

  void clearInk() {
    _clearRevision++;
    _recognizedText = '';
    _strokes = const <InkStrokeData>[];
    _inkMetrics = InkMetrics.empty;
    notifyListeners();
  }

  /// 지금 문제의 답을 기록하고 다음 문제로 넘어갑니다.
  ///
  /// 마지막 문제였다면 그대로 서버에 제출합니다.
  /// 답이 비어 있으면 아무 일도 하지 않고 false를 돌려줍니다.
  Future<bool> submitCurrentProblem() async {
    if (_phase != RankedPhase.playing) return false;
    final raw = _recognizedText.isEmpty ? _manualFallback : _recognizedText;
    // 서버가 채점 직전에 하는 정리를 그대로 미리 합니다.
    final normalized = normalizeMathAnswer(raw);
    if (normalized.isEmpty) return false;

    _recordAnswer(normalized);
    if (_answers.length >= problemCount) {
      await _finish();
    } else {
      notifyListeners();
    }
    return true;
  }

  /// 남은 문제를 빈 답으로 채우고 바로 제출합니다.
  Future<void> giveUpAndSubmit() async {
    if (_phase != RankedPhase.playing) return;
    while (_answers.length < problemCount) {
      _recordAnswer('', graded: false);
    }
    await _finish();
  }

  void _recordAnswer(String text, {bool graded = true}) {
    final startedAt = _problemStartedAt ?? _now();
    final elapsedMs = _now().difference(startedAt).inMilliseconds.clamp(250, 99999);
    final problem = _answers.length < _problems.length ? _problems[_answers.length] : null;

    if (graded && problem != null) {
      final correct = text == problem.answer.toString();
      _lastAnswerCorrect = correct;
      _lastExpectedAnswer = problem.answer;
      _lastSubmittedAnswer = text;
      if (correct) {
        _localCorrectCount++;
        _localCombo++;
      } else {
        _localCombo = 0;
      }
    }

    _answers.add(
      RankedSubmissionAnswer(
        text: text,
        elapsedMs: elapsedMs,
        strokeCount: _inkMetrics.strokeCount,
        pointCount: _inkMetrics.pointCount,
        inkHash: inkHashOf(_strokes),
      ),
    );

    _currentIndex = _answers.length;
    _clearRevision++;
    _resetInput();
    _problemStartedAt = _now();
  }

  Future<void> _finish() async {
    final sessionId = _envelope?.sessionId;
    if (sessionId == null) return;

    _expiryTicker?.cancel();
    _expiryTicker = null;
    _phase = RankedPhase.submitting;
    notifyListeners();

    try {
      _result = await _sessionRepository.submitRankedSession(
        sessionId: sessionId,
        answers: List<RankedSubmissionAnswer>.unmodifiable(_answers),
      );
      _phase = RankedPhase.done;
    } catch (error) {
      _fail(error);
    }
    notifyListeners();
  }

  void _startExpiryTicker() {
    _expiryTicker?.cancel();
    _expiryTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = timeLeft;
      if (left == null) return;
      if (_phase == RankedPhase.playing && left <= autoSubmitMargin) {
        unawaited(giveUpAndSubmit());
        return;
      }
      notifyListeners();
    });
  }

  void _resetInput() {
    _recognizedText = '';
    _manualFallback = '';
    _strokes = const <InkStrokeData>[];
    _inkMetrics = InkMetrics.empty;
  }

  void _fail(Object error) {
    _expiryTicker?.cancel();
    _expiryTicker = null;
    _phase = RankedPhase.failed;
    _errorMessage = describeRankedError(error);
  }

  @override
  void dispose() {
    _expiryTicker?.cancel();
    super.dispose();
  }
}

/// 서버 오류를 화면에 그대로 보여 줄 수 있는 문장으로 바꿉니다.
String describeRankedError(Object error) {
  final code = error is FirebaseFunctionsException ? error.code : '';
  switch (code) {
    case 'failed-precondition':
      return '학교와 지역을 먼저 저장해야 랭크전에 참여할 수 있어요.';
    case 'unauthenticated':
      return '로그인이 풀렸어요. 앱을 다시 열어 주세요.';
    case 'deadline-exceeded':
      return '시간이 지나서 이번 판은 기록되지 않았어요.';
    case 'permission-denied':
      return '이 판은 다른 사람의 기록이라 제출할 수 없어요.';
    case 'unavailable':
      return '네트워크가 불안정해요. 잠시 후 다시 해 주세요.';
    default:
      return '기록을 보내지 못했어요. 잠시 후 다시 시도해 주세요.';
  }
}
