enum GameMode {
  simpleCalculation,
  fourOperations,
  doubleDigit,
  tripleDigit,
}

class GameModeConfig {
  const GameModeConfig({
    required this.mode,
    required this.label,
    required this.description,
    required this.initialTimeMs,
    required this.bonusTimeMs,
    required this.maxTimeMs,
    required this.targetCorrectPerMinute,
  });

  final GameMode mode;
  final String label;
  final String description;
  final int initialTimeMs;
  final int bonusTimeMs;
  final int maxTimeMs;
  final double targetCorrectPerMinute;

  static const all = <GameModeConfig>[
    GameModeConfig(
      mode: GameMode.simpleCalculation,
      label: '단순계산',
      description: '한 자리 덧셈과 뺄셈',
      initialTimeMs: 45000,
      bonusTimeMs: 1700,
      maxTimeMs: 62000,
      targetCorrectPerMinute: 26,
    ),
    GameModeConfig(
      mode: GameMode.fourOperations,
      label: '사칙연산',
      description: '더하기, 빼기, 곱하기, 나누기',
      initialTimeMs: 55000,
      bonusTimeMs: 1500,
      maxTimeMs: 72000,
      targetCorrectPerMinute: 18,
    ),
    GameModeConfig(
      mode: GameMode.doubleDigit,
      label: '두자리수',
      description: '두 자리 수 중심 연산',
      initialTimeMs: 60000,
      bonusTimeMs: 1400,
      maxTimeMs: 76000,
      targetCorrectPerMinute: 14,
    ),
    GameModeConfig(
      mode: GameMode.tripleDigit,
      label: '세자리수',
      description: '세 자리 수 중심 연산',
      initialTimeMs: 70000,
      bonusTimeMs: 1300,
      maxTimeMs: 86000,
      targetCorrectPerMinute: 10,
    ),
  ];

  static GameModeConfig fromMode(GameMode mode) {
    return all.firstWhere((config) => config.mode == mode);
  }
}
