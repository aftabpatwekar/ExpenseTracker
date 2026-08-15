import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../data/category_repository.dart';
import '../../data/expense_repository.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/expense_category.dart';
import '../entry/add_expense_sheet.dart';
import '../entry/expense_actions.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<Expense> _results(
      List<Expense> all, Map<String, ExpenseCategory> catMap) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return all.where((e) {
      final cat = catMap[e.categoryId]?.name.toLowerCase() ?? '';
      final note = e.note.toLowerCase();
      final tags = e.tags.join(' ').toLowerCase();
      final amount = trimAmount(e.amount);
      return note.contains(q) ||
          cat.contains(q) ||
          tags.contains(q) ||
          amount.contains(q);
    }).toList()
      ..sort((a, b) => b.spentAt.compareTo(a.spentAt));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = ref.watch(expensesProvider).asData?.value ?? const <Expense>[];
    final cats =
        ref.watch(categoriesProvider).asData?.value ?? const <ExpenseCategory>[];
    final catMap = {for (final c in cats) c.id: c};
    final results = _results(all, catMap);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(
            hintText: 'Search notes, categories, tags, amounts…',
            border: InputBorder.none,
            filled: false,
            suffixIcon: _q.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() => _q = '');
                    },
                  ),
          ),
        ),
      ),
      body: _q.trim().isEmpty
          ? _hint(theme)
          : results.isEmpty
              ? Center(
                  child: Text('No matches for “$_q”',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.lg, AppSpace.sm, AppSpace.lg, 24),
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final e = results[i];
                    final cat = catMap[e.categoryId];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.sm),
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        onTap: () => showEditExpenseSheet(context, e),
                        onLongPress: () => showExpenseActions(context, e),
                        child: Row(
                          children: [
                            Text(cat?.icon ?? '•',
                                style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: AppSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      e.note.isEmpty
                                          ? (cat?.name ?? 'Other')
                                          : e.note,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600)),
                                  Text(
                                      '${cat?.name ?? 'Uncategorized'} · '
                                      '${formatDay(e.spentAt)}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.outline)),
                                ],
                              ),
                            ),
                            Text(
                                '${e.isIncome ? '+' : ''}${formatMoney(e.amount)}',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: e.isIncome ? kIncome : null)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _hint(ThemeData theme) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: AppSpace.md),
            Text('Search your transactions',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Try a shop name, category, tag, or amount',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      );
}
