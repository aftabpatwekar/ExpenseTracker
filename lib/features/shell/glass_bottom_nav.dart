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
                  Expanded(child: Center(child: _addButton())),
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
        ? kAccentBlue
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

  Widget _addButton() {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: kAccentGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: kAccent.withAlpha(130),
                blurRadius: 16,
                offset: const Offset(0, 6)),
          ],
        ),
        child: const Icon(Icons.add, color: kInk, size: 28),
      ),
    );
  }
}
