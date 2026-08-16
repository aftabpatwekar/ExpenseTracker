import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/app_prefs.dart';
import 'core/env.dart';
import 'core/notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load Supabase URL + anon key from the bundled .env.
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: Env.supabaseUrl,
    // The legacy "anon" key is passed here as the publishable client key.
    publishableKey: Env.supabaseAnonKey,
  );

  // Local notifications aren't supported on web — skip so the PWA can boot.
  if (!kIsWeb) {
    try {
      await NotificationService.init();
    } catch (_) {
      // Non-fatal: continue without local notifications.
    }
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    child: const ExpenseApp(),
  ));
}
