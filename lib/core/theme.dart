import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand accents (premium fintech: blue → violet, with a gold highlight).
const Color kAccent = Color(0xFF6C5CE7); // violet (seed)
const Color kAccentBlue = Color(0xFF4F7DF9);
const Color kAccentViolet = Color(0xFF8E5CF7);
const Color kGold = Color(0xFFF6C445);

const Color kDarkBg = Color(0xFF0A0E27);
const Color kLightBg = Color(0xFFF3F5FE);

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
  );
  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? kDarkBg : kLightBg,
  );
  return base.copyWith(
    textTheme: GoogleFonts.ibmPlexSansTextTheme(base.textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    dividerTheme: DividerThemeData(
      color: (dark ? Colors.white : Colors.black).withAlpha(20),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: (dark ? Colors.white : Colors.black).withAlpha(dark ? 14 : 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
            color: (dark ? Colors.white : Colors.black).withAlpha(30)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
            color: (dark ? Colors.white : Colors.black).withAlpha(30)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kAccent, width: 1.6),
      ),
    ),
  );
}
