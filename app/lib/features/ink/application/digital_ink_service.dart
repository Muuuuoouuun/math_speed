import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart';

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
    // ModelManager는 모델 객체가 아니라 BCP 47 언어 태그 문자열을 받습니다.
    final isDownloaded = await _modelManager.isModelDownloaded(_languageCode);
    if (!isDownloaded) {
      await _modelManager.downloadModel(_languageCode);
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

    final best = candidates.first;
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
