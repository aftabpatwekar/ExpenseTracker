import 'dart:ui';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Full-screen background. Dark = near-black with a faint accent glow so the
/// app reads black (not navy); light = soft tinted wash.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF0C0C10), Color(0xFF090909), Color(0xFF060606)]
              : const [Color(0xFFEFF1FA), Color(0xFFF6F7FE), Color(0xFFEFF1FA)],
        ),
      ),
      child: Stack(
        children: [
          // A single soft glow at the top — subtle depth, still reads black.
          _blob(const Alignment(0.0, -1.15), kAccent, dark ? 46 : 40, 340),
          _blob(const Alignment(1.2, -0.5), kAccentBlue, dark ? 30 : 34, 240),
          Positioned.fill(child: child),
        ],
      ),
    );
  }

  Widget _blob(Alignment align, Color color, int alpha, double size) {
    return Align(
      alignment: align,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
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

/// Elevated card. Dark = neutral dark-grey surface with a hairline border;
/// light = white with a soft border. Light blur keeps it cheap on Android.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.radius = AppRadius.lg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = dark ? Colors.white.withAlpha(13) : Colors.white.withAlpha(235);
    final border =
        dark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(12);

    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
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

/// A pill-shaped sliding segmented control on a glass track — the "common glass
/// bar" used at the top of Analysis. Animates the selected thumb between tabs.
class GlassSegmented extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  const GlassSegmented({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
            color: dark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(10)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedAlign(
                alignment: Alignment(
                    labels.length == 1
                        ? 0
                        : -1 + 2 * selected / (labels.length - 1),
                    0),
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: w,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: kAccentGradient,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: [
                      BoxShadow(
                          color: kAccent.withAlpha(90),
                          blurRadius: 12,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(i),
                        child: SizedBox(
                          height: 36,
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: theme.textTheme.labelLarge!.copyWith(
                                color: i == selected
                                    ? Colors.white
                                    : theme.colorScheme.outline,
                                fontWeight: i == selected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                              child: Text(labels[i]),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
