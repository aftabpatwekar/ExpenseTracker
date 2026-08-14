import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../data/budget_repository.dart';
import '../../data/expense_repository.dart';
import '../../domain/models/budget.dart';
import '../../domain/models/expense.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final budgets =
        ref.watch(budgetsProvider).asData?.value ?? const <Budget>[];
    final expenses =
        ref.watch(expensesProvider).asData?.value ?? const <Expense>[];
    final now = DateTime.now();

    final monthSpent = expenses
        .where((e) => e.spentAt.year == now.year && e.spentAt.month == now.month)
        .fold<double>(0, (s, e) => s + e.amount);
    final yearSpent = expenses
        .where((e) => e.spentAt.year == now.year)
        .fold<double>(0, (s, e) => s + e.amount);

    double budgetFor(String period) {
      final b = budgets.where((x) => x.period == period && x.categoryId == null);
      return b.isEmpty ? 0 : b.first.amount;
    }

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Budgets')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _BudgetCard(
              title: 'Monthly budget',
              spent: monthSpent,
              budget: budgetFor('monthly'),
              onEdit: () =>
                  _edit(context, ref, 'monthly', budgetFor('monthly')),
            ),
            const SizedBox(height: 14),
            _BudgetCard(
              title: 'Annual budget',
              spent: yearSpent,
              budget: budgetFor('annual'),
              onEdit: () => _edit(context, ref, 'annual', budgetFor('annual')),
            ),
            const SizedBox(height: 18),
            Text(
              'The ring shows what you’ve spent this period against the limit '
              'you set. Set the amount to 0 to remove a limit.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, String period, double current) async {
    final ctrl = TextEditingController(
        text: current > 0 ? current.toStringAsFixed(0) : '');
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(period == 'monthly' ? 'Monthly budget' : 'Annual budget'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              const InputDecoration(prefixText: '₹ ', hintText: 'Amount'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(ctrl.text.trim()) ?? 0),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    try {
      await ref.read(budgetRepositoryProvider).setOverall(period, result);
      ref.invalidate(budgetsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(period == 'annual'
              ? 'Annual budgets need migration 002 run in Supabase.'
              : 'Could not save the budget.'),
        ));
      }
    }
  }
}

class _BudgetCard extends StatelessWidget {
  final String title;
  final double spent;
  final double budget;
  final VoidCallback onEdit;
  const _BudgetCard({
    required this.title,
    required this.spent,
    required this.budget,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final has = budget > 0;
    final pct = has ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final over = has && spent > budget;
    final ringColor = over ? Colors.redAccent : kAccentBlue;

    return GlassCard(
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 92,
                  height: 92,
                  child: CircularProgressIndicator(
                    value: has ? pct : 0,
                    strokeWidth: 9,
                    backgroundColor: ringColor.withAlpha(40),
                    valueColor: AlwaysStoppedAnimation(ringColor),
                  ),
                ),
                Text(has ? '${(pct * 100).round()}%' : '—',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                if (has) ...[
                  Text('${formatMoney(spent)} of ${formatMoney(budget)}',
                      style: theme.textTheme.bodyMedium),
                  Text(
                      over
                          ? 'Over by ${formatMoney(spent - budget)}'
                          : '${formatMoney(budget - spent)} left',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: over
                              ? Colors.redAccent
                              : theme.colorScheme.outline)),
                ] else
                  Text('Spent ${formatMoney(spent)} · no limit set',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                const SizedBox(height: 8),
                OutlinedButton(
                    onPressed: onEdit,
                    child: Text(has ? 'Edit' : 'Set budget')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
