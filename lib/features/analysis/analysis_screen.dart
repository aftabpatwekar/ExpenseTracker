import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/hex.dart';
import '../../data/category_repository.dart';
import '../../data/expense_repository.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/expense_category.dart';
import '../dashboard/dashboard_charts.dart';

class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final expenses =
        ref.watch(expensesProvider).asData?.value ?? const <Expense>[];
    final cats =
        ref.watch(categoriesProvider).asData?.value ?? const <ExpenseCategory>[];
    final catMap = {for (final c in cats) c.id: c};
    final now = DateTime.now();
    final monthExpenses = expenses
        .where((e) => e.spentAt.year == now.year && e.spentAt.month == now.month)
        .toList();

    final totals = <String, double>{};
    for (final e in monthExpenses) {
      final id = e.categoryId ?? 'other';
      totals[id] = (totals[id] ?? 0) + e.amount;
    }
    final total = totals.values.fold<double>(0, (s, v) => s + v);
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Analysis',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          if (monthExpenses.isNotEmpty)
            GlassCard(
              child: CategoryDonut(monthExpenses: monthExpenses, catMap: catMap),
            ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0),
          const SizedBox(height: 14),
          if (expenses.isNotEmpty)
            GlassCard(child: MonthlyTrend(expenses: expenses))
                .animate()
                .fadeIn(delay: 100.ms, duration: 350.ms)
                .slideY(begin: 0.08, end: 0),
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This month by category',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('No spending yet this month.',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.outline)),
                  )
                else
                  for (final e in entries)
                    _catRow(context, catMap[e.key], e.value, total),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 350.ms),
        ],
      ),
    );
  }

  Widget _catRow(
      BuildContext context, ExpenseCategory? cat, double amount, double total) {
    final theme = Theme.of(context);
    final color = hexColor(cat?.color ?? '#e34948');
    final pct = total > 0 ? amount / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Text(cat?.icon ?? '•', style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(cat?.name ?? 'Other',
                      style: theme.textTheme.bodyMedium)),
              Text(formatMoney(amount),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: color.withAlpha(40),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
