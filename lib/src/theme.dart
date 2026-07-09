import 'package:flutter/material.dart';

/// Vimer palette + shared visual constants.
class Vim {
  Vim._();

  // Surfaces — flat, neutral graphite chassis so the timer colours are the
  // only colour in the UI. (Swap to 0x..0B0C10/08090C for near-black, or
  // 0x..1A1613/120E0A for warm.)
  static const cardTop = Color(0xF516181E); // ~0.96 alpha
  static const cardBottom = Color(0xF5131519);
  static const glassFill = Color(0x0FFFFFFF);
  static const glassFillStrong = Color(0x17FFFFFF);
  static const fieldFill = Color(0x14FFFFFF);
  static const stroke = Color(0x14FFFFFF);
  static const strokeStrong = Color(0x29FFFFFF);

  // LCD "screen" for the timer readout
  static const screenTop = Color(0xFF0B100E);
  static const screenBottom = Color(0xFF07100C);
  static const screenTopWarm = Color(0xFF17100C);
  static const screenBottomWarm = Color(0xFF120B08);

  // Text
  static const text = Color(0xFFF2F4FA);
  static const textDim = Color(0xFF99A0B3);
  static const textFaint = Color(0xFF565D6E);

  // Accents
  static const mint = Color(0xFF5EE7C7);
  static const blue = Color(0xFF5BB8FF);
  static const amber = Color(0xFFFFC24B);
  static const amber2 = Color(0xFFFF9A70);
  static const ring = Color(0xFFFF7A5E);
  static const ringGlow = Color(0xFFFFA588);

  /// Each timer gets its own colour so they're distinguishable at a glance.
  static const List<Color> timerColors = [
    Color(0xFF5EE7C7), // mint
    Color(0xFF5BB8FF), // sky
    Color(0xFFB794F6), // violet
    Color(0xFF7EE787), // green
    Color(0xFFFF9F7A), // coral
    Color(0xFFFFD166), // gold
    Color(0xFF7AD7F0), // cyan
    Color(0xFFF78FB3), // pink
  ];

  static Color timerColor(int index) => timerColors[index % timerColors.length];
}

const double kPanelRadius = 24;
const double kCardRadius = 18;

ThemeData vimerTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: base.colorScheme.copyWith(
      primary: Vim.mint,
      surface: Vim.cardTop,
    ),
    textTheme: base.textTheme.apply(bodyColor: Vim.text, displayColor: Vim.text),
    sliderTheme: base.sliderTheme.copyWith(
      trackHeight: 4,
      activeTrackColor: Vim.mint,
      inactiveTrackColor: Vim.strokeStrong,
      thumbColor: Colors.white,
      overlayColor: Vim.mint.withValues(alpha: 0.14),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
    ),
  );
}

/// Tabular-figure style so ticking digits never shift width.
const List<FontFeature> kTabular = [FontFeature.tabularFigures()];
