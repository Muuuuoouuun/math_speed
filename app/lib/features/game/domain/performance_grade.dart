import 'game_mode.dart';

class PerformanceGrade {
  const PerformanceGrade({
    required this.label,
    required this.caption,
  });

  final String label;
  final String caption;
}

class PerformanceGrader {
  const PerformanceGrader();

  PerformanceGrade grade({
    required GameMode mode,
    required int correctCount,
    required int attemptCount,
    required int elapsedMs,
  }) {
    if (attemptCount == 0 || elapsedMs <= 0) {
      return const PerformanceGrade(
        label: '거북이',
        caption: '천천히 시작해도 괜찮아요',
      );
    }

    final accuracy = correctCount / attemptCount;
    final correctPerMinute = correctCount / (elapsedMs / 60000);
    final target = GameModeConfig.fromMode(mode).targetCorrectPerMinute;
    final speedRatio = (correctPerMinute / target).clamp(0.0, 1.35);
    final score = (accuracy * 0.58) + (speedRatio * 0.42);

    if (score >= 1.10 && accuracy >= 0.96) {
      return const PerformanceGrade(
        label: '치타',
        caption: '정확도와 속도가 모두 최고예요',
      );
    }
    if (score >= 0.96 && accuracy >= 0.90) {
      return const PerformanceGrade(
        label: '로켓',
        caption: '거의 쉬지 않고 정답을 이어갔어요',
      );
    }
    if (score >= 0.82 && accuracy >= 0.84) {
      return const PerformanceGrade(
        label: '자동차',
        caption: '안정적이고 빠른 페이스예요',
      );
    }
    if (score >= 0.68 && accuracy >= 0.76) {
      return const PerformanceGrade(
        label: '자전거',
        caption: '리듬이 살아나기 시작했어요',
      );
    }
    if (score >= 0.52 && accuracy >= 0.62) {
      return const PerformanceGrade(
        label: '뚜벅이',
        caption: '조금만 더 다듬으면 금방 올라가요',
      );
    }

    return const PerformanceGrade(
      label: '거북이',
      caption: '정확하게 푸는 감각부터 차근차근',
    );
  }
}
