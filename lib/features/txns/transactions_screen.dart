import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/hex.dart';
import '../../data/category_repository.dart';
import '../../data/expense_repository.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/expense_category.dart';
import '../entry/add_expense_sheet.dart';
import '../entry/expense_actions.dart';

enum _Range { thisMonth, last30, all }

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _catId; // null = all categories
  _Range _range = _Range.thisMonth;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _inRange(DateTime d, DateTime now) {
    switch (_range) {
      case _Range.thisMonth:
        return d.year == now.year && d.month == now.month;
      case _Range.last30:
        return d.isAfter(now.subtract(const Duration(days: 30)));
      case _Range.all:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenses =
        ref.watch(expensesProvider).asData?.value ?? const <Expense>[];
    final cats =
        ref.watch(categoriesProvider).asData?.value ?? const <ExpenseCategory>[];
    final catMap = {for (final c in cats) c.id: c};
    final now = DateTime.now();
    final q = _query.trim().toLowerCase();

    final filtered = expenses.where((e) {
      if (!_inRange(e.spentAt, now)) return false;
      if (_catId != null && e.categoryId != _catId) return false;
      if (q.isNotEmpty) {
        final catName = (catMap[e.categoryId]?.name ?? '').toLowerCase();
        final tagHit = e.tags.any((t) => t.toLowerCase().contains(q));
        if (!e.note.toLowerCase().contains(q) &&
            !catName.contains(q) &&
            !tagHit) {
          return false;
        }
      }
      return true;
    }).toList();
    final total = filtered.fold<double>(0, (s, e) => s + e.amount);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Transactions')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search notes or categories',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _RangeChips(
                          value: _range,
                          onChanged: (r) => setState(() => _range = r),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _catChip(context, null, 'All'),
                        for (final c in cats)
                          _catChip(context, c.id, '${c.icon} ${c.name}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('${filtered.length} item${filtered.length == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                  const Spacer(),
                  Text(formatMoney(total),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text('No matching transactions',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.outline)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final e = filtered[i];
                        return _Row(expense: e, cat: catMap[e.categoryId]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _catChip(BuildContext context, String? id, String label) {
    final selected = _catId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _catId = id),
      ),
    );
  }
}

class _RangeChips extends StatelessWidget {
  final _Range value;
  final ValueChanged<_Range> onChanged;
  const _RangeChips({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(_Range r, String label) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: value == r,
            onSelected: (_) => onChanged(r),
          ),
        );
    return Row(
      children: [
        chip(_Range.thisMonth, 'This month'),
        chip(_Range.last30, 'Last 30 days'),
        chip(_Range.all, 'All'),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final Expense expense;
  final ExpenseCategory? cat;
  const _Row({required this.expense, required this.cat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = hexColor(cat?.color ?? '#2a78d6');
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      onTap: () => showEditExpenseSheet(context, expense),
      onLongPress: () => showExpenseActions(context, expense),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: color.withAlpha(45),
                borderRadius: BorderRadius.circular(12)),
            child: Center(
                child:
                    Text(cat?.icon ?? '•', style: const TextStyle(fontSize: 18))),
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
    );
  }
}
