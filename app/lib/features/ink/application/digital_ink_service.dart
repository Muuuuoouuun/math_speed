import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart';

import '../../game/domain/answer_normalizer.dart';
import '../domain/ink_models.dart';

class RecognitionPreview {
  const RecognitionPreview({
    required this.text,
    required this.score,
  });

  final String text;
  final double score;
}

class DigitalInkService {
  DigitalInkService({
    String languageCode = 'ko',
  })  : _languageCode = languageCode,
        _modelManager = DigitalInkRecognizerModelManager();

  final String _languageCode;
  final DigitalInkRecognizerModelManager _modelManager;
  DigitalInkRecognizer? _recognizer;

  Future<void> ensureModelDownloaded() async {
    final isDownloaded = await _modelManager.isModelDownloaded(_languageCode);
    if (!isDownloaded) {
      // 학교 기기는 셀룰러/와이파이 구분 없이 쓰는 경우가 많아 와이파이 제한을 두지 않습니다.
      await _modelManager.downloadModel(_languageCode, isWifiRequired: false);
    }
    _recognizer ??= DigitalInkRecognizer(languageCode: _languageCode);
  }

  Future<RecognitionPreview?> recognize(
    List<InkStrokeData> strokes, {
    double writingAreaWidth = 320,
    double writingAreaHeight = 180,
  }) async {
    if (strokes.isEmpty) {
      return null;
    }

    _recognizer ??= DigitalInkRecognizer(languageCode: _languageCode);

    final ink = Ink()
      ..strokes = strokes
          .map(
            (strokeData) => Stroke()
              ..points = strokeData.points
                  .map(
                    (point) => StrokePoint(
                      x: point.x,
                      y: point.y,
                      t: point.t,
                    ),
                  )
                  .toList(growable: false),
          )
          .toList(growable: false);

    final context = DigitalInkRecognitionContext(
      writingArea: WritingArea(
        width: writingAreaWidth,
        height: writingAreaHeight,
      ),
    );

    final candidates = await _recognizer!.recognize(ink, context: context);
    if (candidates.isEmpty) {
      return null;
    }

    // 후보는 신뢰도 순으로 오므로, 숫자로 읽히는 첫 후보를 고릅니다. (예: 'l0' 대신 '10')
    final best = candidates.firstWhere(
      (candidate) => normalizeAnswer(candidate.text).isNotEmpty,
      orElse: () => candidates.first,
    );
    return RecognitionPreview(
      text: best.text,
      score: best.score,
    );
  }

  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}
