import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ============================================================================
//  Molbhav brand system
//  Bazaar Ink (deep indigo) · Marigold (gold) · Chuna Cream · Sindoor (alert)
// ============================================================================
const Color kInk = Color(0xFF12233F); // Bazaar Ink — deepest brand navy
const Color kInkLight = Color(0xFF24406B); // Ink Light
const Color kMarigold = Color(0xFFF2A20C); // primary accent / button fill
const Color kMarigoldLight = Color(0xFFFFC24A);
const Color kCream = Color(0xFFFBF6EC); // Chuna Cream — light background
const Color kSindoor = Color(0xFFC1502E); // alert / spend

// Legacy aliases kept so existing widgets stay on-brand without churn.
const Color kAccent = kMarigold;
const Color kAccentBlue = kMarigold;
const Color kAccentViolet = kMarigoldLight;
const Color kGold = kMarigoldLight;

// Semantic money colors.
const Color kSpend = kSindoor;
const Color kIncome = Color(0xFF1FA971);

// --- Dark palette: near-black with a faint ink warmth (reads black, not navy). ---
const Color kDarkBg = Color(0xFF090A0D);
const Color kDarkSurface = Color(0xFF141822);
const Color kDarkSurface2 = Color(0xFF1E2430);

// --- Light palette: cream. ---
const Color kLightBg = kCream;
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

/// Brand gradient — marigold. Put INK (kInk) text/icons on top (AAA contrast).
const LinearGradient kAccentGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kMarigoldLight, kMarigold],
);

/// User-selectable accent colors. First entry (Marigold) is the brand default.
class AccentOption {
  final String name;
  final Color color;
  const AccentOption(this.name, this.color);
}

const List<AccentOption> kAccentOptions = [
  AccentOption('Marigold', kMarigold),
  AccentOption('Royal Blue', Color(0xFF4F7DF9)),
  AccentOption('Emerald', Color(0xFF1FA971)),
  AccentOption('Violet', Color(0xFF8E5CF7)),
  AccentOption('Rose', Color(0xFFF43F6B)),
  AccentOption('Cyan', Color(0xFF12B6C9)),
];

/// Contrasting on-accent color (ink for light accents like marigold, else white).
Color onAccentOf(Color accent) =>
    accent.computeLuminance() > 0.5 ? kInk : Colors.white;

/// A gradient built from any accent (lighter → base).
LinearGradient accentGradientOf(Color accent) => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color.lerp(accent, Colors.white, 0.22)!, accent],
    );

/// Accent gradient for the current theme.
LinearGradient accentGradient(BuildContext context) =>
    accentGradientOf(Theme.of(context).colorScheme.primary);

ThemeData buildTheme(Brightness brightness, [Color accent = kMarigold]) {
  final dark = brightness == Brightness.dark;
  final onAcc = onAccentOf(accent);
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
  ).copyWith(
    primary: accent,
    onPrimary: onAcc,
    secondary: kInkLight,
    onSecondary: Colors.white,
    error: kSindoor,
    onError: Colors.white,
    surface: dark ? kDarkBg : kCream,
    onSurface: dark ? const Color(0xFFF3EFE6) : kInk,
    surfaceContainer: dark ? kDarkSurface : kLightSurface,
    surfaceContainerHigh: dark ? kDarkSurface2 : const Color(0xFFF1E9D9),
    surfaceContainerHighest: dark ? kDarkSurface2 : const Color(0xFFEDE4D2),
    outline: dark ? const Color(0xFF8A93A6) : const Color(0xFF6B7385),
    outlineVariant: dark ? const Color(0xFF2A3140) : const Color(0xFFE2D9C6),
  );
  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? kDarkBg : kCream,
    splashFactory: InkSparkle.splashFactory,
  );

  // Inter — the Molbhav brand typeface.
  final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: dark ? const Color(0xFFF3EFE6) : kInk,
    displayColor: dark ? const Color(0xFFF3EFE6) : kInk,
  );

  return base.copyWith(
    textTheme: textTheme.copyWith(
      headlineSmall: textTheme.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      titleLarge: textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700, letterSpacing: 0.8, fontSize: 15),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    chipTheme: ChipThemeData(
      backgroundColor: dark ? const Color(0xFF262D3A) : const Color(0xFFF1E9D9),
      selectedColor: accent,
      side: BorderSide(
          color: dark ? Colors.white.withAlpha(22) : Colors.black.withAlpha(14)),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill)),
      labelStyle: TextStyle(
          color: dark ? const Color(0xFFF3EFE6) : kInk,
          fontWeight: FontWeight.w600),
      secondaryLabelStyle:
          TextStyle(color: onAcc, fontWeight: FontWeight.w700),
      showCheckmark: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF262D3A) : const Color(0xFFF1E9D9),
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
        borderSide: BorderSide(color: accent, width: 1.6),
      ),
    ),
  );
}
