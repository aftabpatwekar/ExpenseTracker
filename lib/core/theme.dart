import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand accents (premium fintech: blue → violet, with a gold highlight).
const Color kAccent = Color(0xFF6C5CE7); // violet (seed)
const Color kAccentBlue = Color(0xFF4F7DF9);
const Color kAccentViolet = Color(0xFF8E5CF7);
const Color kGold = Color(0xFFF6C445);

// Semantic money colors, tuned for a near-black surface.
const Color kSpend = Color(0xFFFF6B6B);
const Color kIncome = Color(0xFF3BD68A);

// --- Dark palette: near-black, only a whisper of cool tint (not navy). ---
const Color kDarkBg = Color(0xFF0A0A0C); // app background
const Color kDarkSurface = Color(0xFF141416); // cards / sheets
const Color kDarkSurface2 = Color(0xFF1D1D21); // raised chips / inputs

// --- Light palette. ---
const Color kLightBg = Color(0xFFF4F5F9);
const Color kLightSurface = Color(0xFFFFFFFF);

/// Spacing + radius tokens — one scale used everywhere for consistency.
class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 24;
  static const double pill = 999;
}

/// Gradient used on the hero total card, the center add button, etc.
const LinearGradient kAccentGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kAccentBlue, kAccent, kAccentViolet],
);

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: kAccent,
    brightness: brightness,
  ).copyWith(
    surface: dark ? kDarkBg : kLightBg,
    surfaceContainer: dark ? kDarkSurface : kLightSurface,
    surfaceContainerHigh: dark ? kDarkSurface2 : const Color(0xFFEDEEF4),
    outline: dark ? const Color(0xFF8A8A93) : const Color(0xFF6B6B75),
    outlineVariant: dark ? const Color(0xFF2A2A30) : const Color(0xFFDADBE3),
  );
  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? kDarkBg : kLightBg,
    splashFactory: InkSparkle.splashFactory,
  );

  // Plus Jakarta Sans — clean, modern, premium at every size.
  final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
    bodyColor: dark ? Colors.white : const Color(0xFF14141A),
    displayColor: dark ? Colors.white : const Color(0xFF14141A),
  );

  return base.copyWith(
    textTheme: textTheme.copyWith(
      headlineSmall: textTheme.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      titleLarge: textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: dark ? const Color(0xFF26262C) : const Color(0xFFECEDF4),
      selectedColor: kAccent,
      side: BorderSide(
          color: dark ? Colors.white.withAlpha(22) : Colors.black.withAlpha(12)),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill)),
      labelStyle: TextStyle(
          color: dark ? Colors.white : const Color(0xFF14141A),
          fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w700),
      showCheckmark: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? kDarkSurface2 : const Color(0xFFECEDF4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: kAccent, width: 1.6),
      ),
    ),
  );
}
