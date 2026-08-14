import 'dart:ui';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Full-screen gradient background with soft glowing blobs for depth.
/// Wrap top-level screens (shell, sign-in) with this.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF0A0E27), Color(0xFF121A3C), Color(0xFF0B0F2A)]
              : const [Color(0xFFEDF0FF), Color(0xFFF6F7FE), Color(0xFFEAF0FF)],
        ),
      ),
      child: Stack(
        children: [
          _blob(Alignment(-0.9, -0.95), kAccentBlue, dark ? 90 : 55, 260),
          _blob(Alignment(1.1, -0.6), kAccentViolet, dark ? 80 : 45, 220),
          _blob(Alignment(-1.0, 0.9), kAccent, dark ? 70 : 40, 240),
          Positioned.fill(child: child),
        ],
      ),
    );
  }

  Widget _blob(Alignment align, Color color, int alpha, double size) {
    return Align(
      alignment: align,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withAlpha(alpha),
          ),
        ),
      ),
    );
  }
}

/// Frosted-glass card: backdrop blur + translucent fill + hairline light border.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = (dark ? Colors.white : Colors.white).withAlpha(dark ? 20 : 205);
    final border = Colors.white.withAlpha(dark ? 38 : 235);

    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: border, width: 1),
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: card,
        ),
      );
    }
    return card;
  }
}
