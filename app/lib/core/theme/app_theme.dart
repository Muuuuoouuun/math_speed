import 'package:flutter/material.dart';

import 'app_tokens.dart';

class AppTheme {
  static ThemeData light() {
    final scheme = const ColorScheme.light().copyWith(
      primary: AppPalette.ink,
      onPrimary: Colors.white,
      secondary: AppPalette.mint,
      onSecondary: Colors.white,
      surface: AppPalette.card,
      onSurface: AppPalette.ink,
      surfaceContainerHighest: AppPalette.cardSunk,
      outline: AppPalette.line,
      outlineVariant: AppPalette.lineSoft,
      error: AppPalette.blush,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppPalette.paper,
      splashFactory: InkSparkle.splashFactory,
      textTheme: const TextTheme(
        // 숫자 문제처럼 화면을 지배하는 큰 글자.
        displayLarge: TextStyle(
          fontSize: 64,
          fontWeight: FontWeight.w800,
          letterSpacing: -2,
          height: 1.05,
          color: AppPalette.ink,
        ),
        headlineMedium: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
          height: 1.2,
          color: AppPalette.ink,
        ),
        titleLarge: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          height: 1.3,
          color: AppPalette.ink,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
          height: 1.35,
          color: AppPalette.graphite,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          height: 1.55,
          color: AppPalette.ink,
        ),
        bodyMedium: TextStyle(
          fontSize: 13.5,
          height: 1.5,
          color: AppPalette.muted,
        ),
        // 라벨은 손글씨 메모처럼 자간을 살짝 벌려 씁니다.
        labelLarge: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: AppPalette.muted,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: AppPalette.faint,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.cardSunk,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        labelStyle: const TextStyle(color: AppPalette.muted, fontWeight: FontWeight.w600),
        border: _inputBorder(AppPalette.line),
        enabledBorder: _inputBorder(AppPalette.line),
        focusedBorder: _inputBorder(AppPalette.mint, width: 1.6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppPalette.faint,
          disabledForegroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.graphite,
          backgroundColor: AppPalette.card,
          side: const BorderSide(color: AppPalette.line, width: 1.4),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppPalette.graphite,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll<Color>(AppPalette.card),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppPalette.card,
        selectedColor: AppPalette.ink,
        secondarySelectedColor: AppPalette.ink,
        labelStyle: const TextStyle(color: AppPalette.graphite, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        side: const BorderSide(color: AppPalette.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppPalette.ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppPalette.lineSoft,
        thickness: 1,
        space: AppSpacing.lg,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppPalette.mint,
        linearTrackColor: AppPalette.paperDeep,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1.2}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
