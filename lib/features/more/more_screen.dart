import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/glass.dart';
import '../../data/category_repository.dart';
import '../../data/expense_repository.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/expense_category.dart';
import '../budget/budgets_screen.dart';
import '../category/categories_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _tile(context, Icons.file_download_outlined, 'Export to CSV',
                    'Download all expenses (opens in Excel)',
                    () => _export(context, ref)),
                const Divider(height: 1),
                _tile(context, Icons.savings_outlined, 'Budgets',
                    'Monthly & annual limits',
                    () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const BudgetsScreen()))),
                const Divider(height: 1),
                _tile(context, Icons.category_outlined, 'Categories',
                    'Edit names & keywords',
                    () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const CategoriesScreen()))),
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
