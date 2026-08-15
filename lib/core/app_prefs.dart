import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// Overridden in main() with the loaded instance.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPrefsProvider must be overridden in main()');
});

/// Persisted app theme mode (system / light / dark).
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() => _parse(ref.watch(sharedPrefsProvider).getString(_key));

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPrefsProvider).setString(_key, mode.name);
  }

  static ThemeMode _parse(String? v) {
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

String themeModeLabel(ThemeMode m) => switch (m) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'Follows system',
    };

/// Persisted accent color index into [kAccentOptions] (0 = Marigold default).
class AccentNotifier extends Notifier<int> {
  static const _key = 'accent_index';

  @override
  int build() {
    final i = ref.watch(sharedPrefsProvider).getInt(_key) ?? 0;
    return (i >= 0 && i < kAccentOptions.length) ? i : 0;
  }

  Future<void> set(int index) async {
    state = index;
    await ref.read(sharedPrefsProvider).setInt(_key, index);
  }
}

final accentProvider = NotifierProvider<AccentNotifier, int>(AccentNotifier.new);

/// The currently selected accent color.
final accentColorProvider = Provider<Color>((ref) {
  return kAccentOptions[ref.watch(accentProvider)].color;
});
