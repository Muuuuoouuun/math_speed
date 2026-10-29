import 'package:flutter/material.dart';

/// 연필과 종이 감성을 유지하기 위한 색 팔레트.
///
/// 값은 모두 따뜻한 크림 계열 종이 위에 흑연으로 쓴 화면을 기준으로 잡았고,
/// 강조색은 채도를 낮춰 색연필로 칠한 듯한 톤을 유지합니다.
class AppPalette {
  const AppPalette._();

  // 종이
  static const paper = Color(0xFFFAF4E6);
  static const paperDeep = Color(0xFFF0E5CF);
  static const card = Color(0xFFFFFDF7);
  static const cardSunk = Color(0xFFFBF5E8);

  // 흑연
  static const ink = Color(0xFF2E2A25);
  static const graphite = Color(0xFF55504A);
  static const muted = Color(0xFF8C8479);
  static const faint = Color(0xFFB4AB9C);

  // 선
  static const line = Color(0xFFE3D8C4);
  static const lineSoft = Color(0xFFEFE6D6);
  static const rule = Color(0xFFD7E2EE);
  static const margin = Color(0xFFE0A79E);

  // 색연필 강조색
  static const mint = Color(0xFF6FAE92);
  static const sky = Color(0xFF7CA3CC);
  static const apricot = Color(0xFFE0A163);
  static const blush = Color(0xFFD98A8A);
  static const gold = Color(0xFFD3A03F);
  static const lilac = Color(0xFFA79BC8);

  static const shadow = Color(0x12000000);
  static const shadowSoft = Color(0x0A000000);

  /// 게임 모드 순서대로 쓰는 색연필 색.
  static const List<Color> crayons = <Color>[mint, sky, apricot, lilac];
}

/// 여백 스케일.
///
/// 화면이 넉넉해 보이도록 섹션 사이는 [xl] 이상을 기본으로 씁니다.
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
  static const double xxl = 40;

  /// 화면 좌우 기본 여백.
  static const double gutter = 24;

  /// 넓은 화면에서 한 줄이 지나치게 길어지지 않도록 잡는 상한.
  static const double maxContentWidth = 620;
}

class AppRadius {
  const AppRadius._();

  static const double xs = 12;
  static const double sm = 16;
  static const double md = 22;
  static const double lg = 28;
  static const double xl = 34;
  static const double pill = 999;
}

class AppDuration {
  const AppDuration._();

  static const Duration quick = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 460);
  static const Duration stamp = Duration(milliseconds: 620);
}

/// 남은 시간 비율에 따라 달라지는 강조색.
///
/// 여유 → 민트, 중간 → 살구, 촉박 → 붉은 톤으로 자연스럽게 넘어갑니다.
Color urgencyColor(double ratio) {
  if (ratio > 0.55) return AppPalette.mint;
  if (ratio > 0.28) {
    final t = ((0.55 - ratio) / 0.27).clamp(0.0, 1.0);
    return Color.lerp(AppPalette.mint, AppPalette.apricot, t) ?? AppPalette.apricot;
  }
  final t = ((0.28 - ratio) / 0.28).clamp(0.0, 1.0);
  return Color.lerp(AppPalette.apricot, AppPalette.blush, t) ?? AppPalette.blush;
}
