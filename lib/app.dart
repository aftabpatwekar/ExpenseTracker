import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_prefs.dart';
import 'core/deep_link.dart';
import 'core/theme.dart';
import 'router.dart';

class ExpenseApp extends ConsumerWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Start the app-lifetime deep-link listener (Back-Tap → voice-add).
    ref.watch(deepLinkListenerProvider);
    final router = ref.watch(routerProvider);
    final mode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentColorProvider);
    return MaterialApp.router(
      title: 'Molbhav',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: buildTheme(Brightness.light, accent),
      darkTheme: buildTheme(Brightness.dark, accent),
      routerConfig: router,
      // Clamp system font scaling so a large device font setting (common on
      // Android) can't overflow tight layouts — keeps parity with iOS.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler
                .clamp(minScaleFactor: 1.0, maxScaleFactor: 1.15),
          ),
          child: child!,
        );
      },
    );
  }
}
