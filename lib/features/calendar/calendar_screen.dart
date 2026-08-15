import 'package:flutter/material.dart';
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

const _months = [
  '', 'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December'
];
const _dow = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

String _compact(double v) {
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
  return v.toStringAsFixed(0);
}

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _month; // first of month
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    _selected = DateTime(now.year, now.month, now.day);
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenses =
        ref.watch(expensesProvider).asData?.value ?? const <Expense>[];
    final cats =
        ref.watch(categoriesProvider).asData?.value ?? const <ExpenseCategory>[];
    final catMap = {for (final c in cats) c.id: c};

    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final offset = DateTime(_month.year, _month.month, 1).weekday % 7; // Sun=0

    final byDay = <int, double>{};
    for (final e in expenses) {
      if (e.spentAt.year == _month.year &&
          e.spentAt.month == _month.month &&
          e.isExpense) {
        byDay[e.spentAt.day] = (byDay[e.spentAt.day] ?? 0) + e.amount;
      }
    }

    final dayTx = expenses
        .where((e) => _sameDay(e.spentAt, _selected))
        .toList()
      ..sort((a, b) => b.spentAt.compareTo(a.spentAt));

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Calendar')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                      onPressed: () => _shiftMonth(-1),
                      icon: const Icon(Icons.chevron_left)),
                  Expanded(
                    child: Text('${_months[_month.month]} ${_month.year}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                      onPressed: () => _shiftMonth(1),
                      icon: const Icon(Icons.chevron_right)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final d in _dow)
                    Expanded(
                      child: Center(
                        child: Text(d,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.outline)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7, childAspectRatio: 0.8),
                itemCount: offset + daysInMonth,
                itemBuilder: (context, i) {
                  if (i < offset) return const SizedBox.shrink();
                  final day = i - offset + 1;
                  final date = DateTime(_month.year, _month.month, day);
                  final amount = byDay[day];
                  final selected = _sameDay(date, _selected);
                  return GestureDetector(
                    onTap: () => setState(() => _selected = date),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: selected
                            ? kAccent.withAlpha(60)
                            : (amount != null
                                ? theme.colorScheme.primary.withAlpha(18)
                                : Colors.transparent),
                        borderRadius: BorderRadius.circular(10),
                        border: selected
                            ? Border.all(color: kAccent, width: 1.4)
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$day',
                              style: TextStyle(
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  fontSize: 13)),
                          if (amount != null)
                            Text('₹${_compact(amount)}',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(formatDay(_selected),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('${dayTx.length} item${dayTx.length == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: dayTx.isEmpty
                  ? Center(
                      child: Text('Nothing on this day',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.outline)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: dayTx.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final e = dayTx[i];
                        final cat = catMap[e.categoryId];
                        final color = hexColor(cat?.color ?? '#2a78d6');
                        return GlassCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          onTap: () => showExpenseActions(context, e),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                    color: color.withAlpha(45),
                                    borderRadius: BorderRadius.circular(11)),
                                child: Center(
                                    child: Text(cat?.icon ?? '•',
                                        style: const TextStyle(fontSize: 17))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                    e.note.isEmpty
                                        ? (cat?.name ?? 'Expense')
                                        : e.note,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyLarge
                                        ?.copyWith(fontWeight: FontWeight.w600)),
                              ),
                              Text(
                                  '${e.isIncome ? '+' : ''}${formatMoney(e.amount)}',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: e.isIncome
                                          ? const Color(0xFF1FB56B)
                                          : null)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
