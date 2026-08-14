import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  static const List<Widget> _tabs = [
    HomeTab(),
    AnalysisScreen(),
    AccountScreen(),
    MoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Deep link: expensetracker://add  → jump straight to voice-add.
    // Used by the Android "Speak expense" shortcut and (later) iOS Back Tap.
    _linkSub = _appLinks.uriLinkStream.listen(_handleLink);
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleLink(uri);
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  void _handleLink(Uri uri) {
    if (uri.host == 'add' || uri.pathSegments.contains('add')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showAddExpenseSheet(context, startVoice: true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
