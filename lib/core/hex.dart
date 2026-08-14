import 'package:flutter/painting.dart';

/// Parses a `#rrggbb` (or `#aarrggbb`) hex string into a [Color].
Color hexColor(String s, {Color fallback = const Color(0xFF2A78D6)}) {
  var h = s.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}
