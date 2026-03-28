import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    const canvas = Color(0xFFF3EEE2);
    const surface = Color(0xFFFFFCF6);
    const ink = Color(0xFF2B2926);
    const graphite = Color(0xFF474440);
    const muted = Color(0xFF7D766C);
    const line = Color(0xFFD9D0C0);
    const accent = Color(0xFF363330);

    final scheme = const ColorScheme.light().copyWith(
      primary: accent,
      secondary: graphite,
      surface: surface,
      onSurface: ink,
      outline: line,
    );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: ink,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          height: 1.45,
          color: ink,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          height: 1.35,
          color: muted,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: accent, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: line),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: accent,
        secondarySelectedColor: accent,
        labelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(
        color: line,
        thickness: 1,
      ),
    );
  }
}
