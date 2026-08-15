import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/deep_link.dart';
import '../../core/glass.dart';
import '../../core/home_widget_service.dart';
import '../../data/expense_repository.dart';
import '../../data/recurring_repository.dart';
import '../../domain/models/expense.dart';
import '../accounts/accounts_screen.dart';
import '../analysis/analysis_screen.dart';
import '../auth/set_password_sheet.dart';
import '../dashboard/dashboard_screen.dart';
import '../entry/add_expense_sheet.dart';
import '../more/more_screen.dart';
import 'glass_bottom_nav.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  bool _addSheetOpen = false;
  StreamSubscription<AuthState>? _authSub;

  static const List<Widget> _tabs = [
    HomeTab(),
    AnalysisScreen(),
    AccountsScreen(),
    MoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Password reset: opening a reset link fires passwordRecovery.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showSetPasswordSheet(context);
        });
      }
    });
    // Generate any due recurring transactions on open.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final created = await ref.read(recurringRepositoryProvider).catchUp();
      if (created > 0 && mounted) ref.invalidate(expensesProvider);
    });
    // Cold start: a deep link may already be pending before this mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(pendingAddProvider)) _openVoiceAdd();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  /// Open the voice-add sheet once, clearing the pending flag. Guards against
  /// opening two sheets if the flag toggles while one is already up.
  void _openVoiceAdd() {
    if (_addSheetOpen || !mounted) return;
    ref.read(pendingAddProvider.notifier).set(false);
    _addSheetOpen = true;
    showAddExpenseSheet(context, startVoice: true)
        .whenComplete(() => _addSheetOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    // Warm start: link arrives (flag flips true) while the app is already open.
    ref.listen<bool>(pendingAddProvider, (_, next) {
      if (next) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _openVoiceAdd());
      }
    });
    // Keep the home-screen widget in sync whenever expenses load or change.
    ref.listen<AsyncValue<List<Expense>>>(expensesProvider, (_, next) {
      final data = next.asData?.value;
      if (data != null) HomeWidgetService.push(data);
    });
    final dlDebug = ref.watch(deepLinkDebugProvider);
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: Stack(
          children: [
            IndexedStack(index: _index, children: _tabs),
            // TEMPORARY diagnostic banner (remove once Back-Tap is confirmed).
            Positioned(
              top: MediaQuery.of(context).padding.top + 4,
              left: 8,
              right: 8,
              child: IgnorePointer(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'BUILD v1.0.1 • DL: $dlDebug',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: GlassBottomNav(
          index: _index,
          onTap: (i) => setState(() => _index = i),
          onAdd: () => showAddExpenseSheet(context),
        ),
      ),
    );
  }
}
