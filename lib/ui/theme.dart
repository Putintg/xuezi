import 'package:flutter/material.dart';

/// Цвета «бумага и тушь»: тёплый фон, киноварь как акцент.
class Palette {
  static const paper = Color(0xFFF7F2E9);
  static const ink = Color(0xFF1F1B16);
  static const cinnabar = Color(0xFFC0392B);
  static const jade = Color(0xFF2E7D6B);
  static const muted = Color(0xFF7A6F63);

  static const levelColors = [
    Color(0xFF2E7D6B),
    Color(0xFF3B6EA8),
    Color(0xFFB7791F),
    Color(0xFFC0392B),
  ];

  static Color level(int l) => levelColors[(l - 1).clamp(0, 3)];
}

ThemeData buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.cinnabar,
    brightness: b,
    surface: b == Brightness.light ? Palette.paper : const Color(0xFF1A1714),
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
      elevation: 0,
      color: b == Brightness.light ? Colors.white : const Color(0xFF26221E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}

/// Крупный иероглиф.
TextStyle hanziStyle(double size, {Color? color}) => TextStyle(
      fontSize: size,
      height: 1.1,
      color: color,
      fontWeight: FontWeight.w400,
      fontFamilyFallback: const ['Noto Serif CJK SC', 'Noto Sans CJK SC'],
    );
