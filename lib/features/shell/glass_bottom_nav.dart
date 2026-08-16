import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Floating frosted nav bar: Home · Stats · [Add] · Account · More.
class GlassBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;
  const GlassBottomNav({
    super.key,
    required this.index,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 66,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(dark ? 26 : 205),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withAlpha(dark ? 40 : 235)),
              ),
              child: Row(
                children: [
                  _item(context, Icons.home_rounded, 'Home', 0),
                  _item(context, Icons.pie_chart_rounded, 'Stats', 1),
                  Expanded(child: Center(child: _MorphingAddButton(onTap: onAdd))),
                  _item(context, Icons.account_balance_wallet_rounded, 'Accounts', 2),
                  _item(context, Icons.more_horiz_rounded, 'More', 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String label, int i) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selected = index == i;
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : (dark ? Colors.white70 : Colors.black54);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(i),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    height: 1,
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }

}

/// Center action button. Voice is our USP, so it morphs between a "+" and a mic
/// every few seconds (spin + fade) with a gentle pulsing glow. Tap OR long-press
/// starts a voice-add.
class _MorphingAddButton extends StatefulWidget {
  final VoidCallback onTap;
  const _MorphingAddButton({required this.onTap});

  @override
  State<_MorphingAddButton> createState() => _MorphingAddButtonState();
}

class _MorphingAddButtonState extends State<_MorphingAddButton>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  bool _mic = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _mic = !_mic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onAcc = onAccentOf(primary);
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: accentGradient(context),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primary.withAlpha(120),
                blurRadius: 14 + _pulse.value * 12,
                spreadRadius: _pulse.value * 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          transitionBuilder: (child, anim) => RotationTransition(
            turns: Tween<double>(begin: 0.6, end: 1.0).animate(anim),
            child: ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
          ),
          child: Icon(
            _mic ? Icons.mic_rounded : Icons.add,
            key: ValueKey(_mic),
            color: onAcc,
            size: 28,
          ),
        ),
      ),
    );
  }
}
