import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand colors
  static const Color copper = Color(0xFFD99459);
  static const Color copperLight = Color(0xFFFFD5A3);

  // Background colors
  static const Color graphite = Color(0xFF111211);
  static const Color cream = Color(0xFFF8F1E7);
  static const Color warmWhite = Color(0xFFFFFDF9);

  // Text colors
  static const Color lightText = Color(0xFF26231F);
  static const Color darkMuted = Color(0xFFD0D0D0);
  static const Color lightMuted = Color(0xFF6C6258);

  // Shared theme state
  static final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(true);

  // Text colors based on theme
  static Color text(bool dark) => dark ? Colors.white : lightText;

  static Color muted(bool dark) => dark ? darkMuted : lightMuted;

  static Color accentText(bool dark) =>
      dark ? copperLight : const Color(0xFF955426);

  // Input field colors
  static Color fieldFill(bool dark) =>
      dark ? const Color(0xFF242727) : const Color(0xFFFFF8EF);

  static Color fieldBorder(bool dark) =>
      dark ? Colors.white.withValues(alpha: 0.22) : const Color(0xFFD8C5B0);

  // Glassmorphism borders
  static Color glassBorder(bool dark) => dark
      ? Colors.white.withValues(alpha: 0.28)
      : Colors.white.withValues(alpha: 0.86);

  // Unified Card & Surface Helpers
  static Color cardColor(bool dark) =>
      dark ? const Color(0xDD1B1E20) : Colors.white.withOpacity(0.91);

  static Border cardBorder(bool dark) => Border.all(
    color: dark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFFE2DED7),
  );

  static List<BoxShadow> cardShadow(bool dark) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: dark ? 0.10 : 0.025),
      blurRadius: 18,
      offset: const Offset(0, 4),
    ),
  ];

  static BoxDecoration cardDecoration(bool dark, {double radius = 16}) =>
      BoxDecoration(
        color: cardColor(dark),
        borderRadius: BorderRadius.circular(radius),
        border: cardBorder(dark),
        boxShadow: cardShadow(dark),
      );

  // Application theme
  static ThemeData theme(bool dark) {
    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: dark ? graphite : cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: copper,
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
    );
  }
}
