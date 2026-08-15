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
      // Compact type scale. A large device font setting (common on Android)
      // made everything oversized; cap at the design size and tighten to 0.9.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final device = mq.textScaler.scale(1.0);
        final eff = (device < 1.0 ? device : 1.0) * 0.9;
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(eff)),
          child: child!,
        );
      },
    );
  }
}
