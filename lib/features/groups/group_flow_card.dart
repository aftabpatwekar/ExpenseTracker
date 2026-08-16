import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/group_repository.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/group.dart';
import 'group_detail_screen.dart';

/// Ink hero card summarising a group's shared spend vs its monthly budget.
/// Used on the Home cash-flow carousel and the Accounts screen. Tap → details.
class GroupFlowCard extends ConsumerWidget {
  final Group group;
  const GroupFlowCard({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses =
        ref.watch(groupExpensesProvider(group.id)).asData?.value ??
            const <Expense>[];
    final budget = ref.watch(groupBudgetProvider(group.id)).asData?.value;
    final now = DateTime.now();
    final monthSpend = expenses
        .where((e) =>
            e.isExpense &&
            e.spentAt.year == now.year &&
            e.spentAt.month == now.month)
        .fold<double>(0, (s, e) => s + e.amount);
    final over = budget != null && monthSpend > budget;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => GroupDetailScreen(group: group))),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kInkLight, kInk],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: kInk.withAlpha(120),
                blurRadius: 24,
                offset: const Offset(0, 12)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.groups_2_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white.withAlpha(38),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Text('SHARED',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('SPENT THIS MONTH',
                style: TextStyle(
                    color: Colors.white.withAlpha(180),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(formatMoney(monthSpend),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 14),
            if (budget != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: budget > 0
                      ? (monthSpend / budget).clamp(0, 1).toDouble()
                      : 0,
                  minHeight: 8,
                  backgroundColor: Colors.white.withAlpha(38),
                  valueColor:
                      AlwaysStoppedAnimation(over ? kSpend : kMarigold),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                  over
                      ? 'Over by ${formatMoney(monthSpend - budget)}'
                      : '${formatMoney(budget - monthSpend)} left of ${formatMoney(budget)}',
                  style: TextStyle(
                      color: over ? const Color(0xFFFFC9B9) : Colors.white70,
                      fontSize: 12)),
            ] else
              Text('No budget set · tap to add one',
                  style: TextStyle(
                      color: Colors.white.withAlpha(180), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
