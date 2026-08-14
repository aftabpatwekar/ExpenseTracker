import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deep_link.dart';
import '../../core/glass.dart';
import '../account/account_screen.dart';
import '../analysis/analysis_screen.dart';
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

  static const List<Widget> _tabs = [
    HomeTab(),
    AnalysisScreen(),
    AccountScreen(),
    MoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Cold start: a deep link may already be pending before this mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(pendingAddProvider)) _openVoiceAdd();
    });
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
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: IndexedStack(index: _index, children: _tabs),
        bottomNavigationBar: GlassBottomNav(
          index: _index,
          onTap: (i) => setState(() => _index = i),
          onAdd: () => showAddExpenseSheet(context),
        ),
      ),
    );
  }
}
