import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_prefs.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../data/category_repository.dart';
import '../../data/expense_repository.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/expense_category.dart';
import '../auth/auth_repository.dart';
import '../budget/budgets_screen.dart';
import '../calendar/calendar_screen.dart';
import '../category/categories_screen.dart';
import '../groups/groups_screen.dart';
import '../recurring/scheduled_screen.dart';
import '../reports/reports_screen.dart';
import 'excel_export.dart';
import 'reminders_sheet.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final email = ref.watch(authRepositoryProvider).currentUser?.email ?? 'you';
    final mode = ref.watch(themeModeProvider);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('More',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          GlassCard(
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                      gradient: kAccentGradient, shape: BoxShape.circle),
                  child: Center(
                      child: Text(
                          email.isNotEmpty ? email[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Signed in',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline)),
                      Text(email,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                  icon: const Icon(Icons.logout),
                  tooltip: 'Sign out',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _tile(context, Icons.description_outlined, 'Reports',
                    'Filter & download CSV, Excel or PDF',
                    () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ReportsScreen()))),
                const Divider(height: 1),
                _tile(context, Icons.file_download_outlined, 'Export to CSV',
                    'Download all expenses (opens in Excel)',
                    () => _export(context, ref)),
                const Divider(height: 1),
                _tile(context, Icons.table_chart_outlined, 'Export to Excel',
                    'Download a formatted .xlsx',
                    () => exportExcel(context, ref)),
                const Divider(height: 1),
                _tile(context, Icons.savings_outlined, 'Budgets',
                    'Monthly & annual limits',
                    () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const BudgetsScreen()))),
                const Divider(height: 1),
                _tile(context, Icons.groups_2_outlined, 'Groups',
                    'Share a budget with others',
                    () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const GroupsScreen()))),
                const Divider(height: 1),
                _tile(context, Icons.category_outlined, 'Categories',
                    'Edit names & keywords',
                    () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const CategoriesScreen()))),
                const Divider(height: 1),
                _tile(context, Icons.event_repeat_outlined, 'Scheduled',
                    'Recurring transactions',
                    () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ScheduledScreen()))),
                const Divider(height: 1),
                _tile(context, Icons.calendar_month_outlined, 'Calendar',
                    'Transactions by day',
                    () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const CalendarScreen()))),
                const Divider(height: 1),
                _tile(context, Icons.notifications_none, 'Reminders',
                    'Daily nudge to log expenses',
                    () => showRemindersSheet(context)),
                const Divider(height: 1),
                _tile(context, Icons.brightness_6_outlined, 'Appearance',
                    themeModeLabel(mode), () => _pickTheme(context, ref, mode)),
                const Divider(height: 1),
                _tile(context, Icons.info_outline, 'About',
                    'Expense Tracker · v1.0', null),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title,
      String subtitle, VoidCallback? onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }

  Future<void> _pickTheme(
      BuildContext context, WidgetRef ref, ThemeMode current) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in ThemeMode.values)
              ListTile(
                leading: Icon(m == current
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off),
                title: Text(themeModeLabel(m)),
                onTap: () {
                  ref.read(themeModeProvider.notifier).set(m);
                  Navigator.of(ctx).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _msg(BuildContext context, String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final expenses =
        ref.read(expensesProvider).asData?.value ?? const <Expense>[];
    final cats =
        ref.read(categoriesProvider).asData?.value ?? const <ExpenseCategory>[];
    final catMap = {for (final c in cats) c.id: c};
    if (expenses.isEmpty) {
      _msg(context, 'No expenses to export yet');
      return;
    }
    final buf = StringBuffer('Date,Amount,Currency,Category,Note\n');
    for (final e in expenses) {
      final cat = catMap[e.categoryId]?.name ?? '';
      final note = e.note.replaceAll('"', '""');
      buf.writeln('${e.spentAt.toIso8601String()},${e.amount},'
          '${e.currency},"$cat","$note"');
    }
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/expenses.csv');
      await file.writeAsString(buf.toString());
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'My expenses export'),
      );
    } catch (_) {
      if (context.mounted) _msg(context, 'Could not export');
    }
  }
}
