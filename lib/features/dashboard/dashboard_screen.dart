import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/hex.dart';
import '../../core/theme.dart';
import '../../data/category_repository.dart';
import '../../data/expense_repository.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/expense_category.dart';
import '../entry/expense_actions.dart';
import '../txns/transactions_screen.dart';
import 'dashboard_charts.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(categoriesProvider);
    ref.invalidate(expensesProvider);
    await ref.read(expensesProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider);
    final categories =
        ref.watch(categoriesProvider).asData?.value ?? const <ExpenseCategory>[];
    final catMap = {for (final c in categories) c.id: c};

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: expensesAsync.when(
          loading: () => ListView(children: const [
            SizedBox(height: 320, child: Center(child: CircularProgressIndicator())),
          ]),
          error: (e, _) => ListView(children: const [
            SizedBox(height: 200),
            Icon(Icons.cloud_off, size: 44),
            SizedBox(height: 12),
            Center(child: Text('Could not load. Pull to retry.')),
          ]),
          data: (expenses) => _Content(expenses: expenses, catMap: catMap),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final List<Expense> expenses;
  final Map<String, ExpenseCategory> catMap;
  const _Content({required this.expenses, required this.catMap});

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final monthExpenses = expenses
        .where((e) => e.spentAt.year == now.year && e.spentAt.month == now.month)
        .toList();
    final monthTotal = monthExpenses.fold<double>(0, (s, e) => s + e.amount);
    final todayTotal = expenses
        .where((e) => _sameDay(e.spentAt, now))
        .fold<double>(0, (s, e) => s + e.amount);
    final recent = expenses.length > 12 ? expenses.sublist(0, 12) : expenses;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome back',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
            Text('Your expenses',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 16),
        _HeroCard(
                total: monthTotal, today: todayTotal, count: monthExpenses.length)
            .animate()
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
        const SizedBox(height: 14),
        if (monthExpenses.isNotEmpty) ...[
          GlassCard(
                  child:
                      CategoryDonut(monthExpenses: monthExpenses, catMap: catMap))
              .animate()
              .fadeIn(delay: 100.ms, duration: 350.ms)
              .slideY(begin: 0.1, end: 0),
          const SizedBox(height: 14),
        ],
        if (expenses.isNotEmpty)
          GlassCard(child: MonthlyTrend(expenses: expenses))
              .animate()
              .fadeIn(delay: 200.ms, duration: 350.ms)
              .slideY(begin: 0.1, end: 0),
        const SizedBox(height: 22),
        Row(
          children: [
            Text('Recent',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            if (expenses.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const TransactionsScreen())),
                child: const Text('See all'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (expenses.isEmpty)
          const _EmptyTx()
        else
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                for (int i = 0; i < recent.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: 1,
                        color: (theme.brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black)
                            .withAlpha(18)),
                  _TxRow(expense: recent[i], cat: catMap[recent[i].categoryId]),
                ],
              ],
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 350.ms),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final double total;
  final double today;
  final int count;
  const _HeroCard(
      {required this.total, required this.today, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: kAccentGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: kAccent.withAlpha(90),
              blurRadius: 26,
              offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Spent this month',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(formatMoney(total),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  height: 1.05)),
          const SizedBox(height: 16),
          Row(
            children: [
              _pill(Icons.today_rounded, 'Today', formatMoney(today)),
              const SizedBox(width: 10),
              _pill(Icons.receipt_long_rounded, 'Entries', '$count'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(38),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11)),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final Expense expense;
  final ExpenseCategory? cat;
  const _TxRow({required this.expense, required this.cat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = hexColor(cat?.color ?? '#2a78d6');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showExpenseActions(context, expense),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: color.withAlpha(45),
                borderRadius: BorderRadius.circular(12)),
            child: Center(
                child: Text(cat?.icon ?? '•',
                    style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.note.isEmpty ? (cat?.name ?? 'Expense') : expense.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text('${cat?.name ?? 'Uncategorized'} · ${formatDay(expense.spentAt)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          ),
          Text(formatMoney(expense.amount),
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
      ),
    );
  }
}

class _EmptyTx extends StatelessWidget {
  const _EmptyTx();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(Icons.mic_none_rounded,
                size: 44, color: theme.colorScheme.outline),
            const SizedBox(height: 10),
            Text('No expenses yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Tap the + and speak or type',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}
