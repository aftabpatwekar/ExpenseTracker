import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../data/account_repository.dart';
import '../../data/category_repository.dart';
import '../../data/expense_repository.dart';
import '../../domain/models/account.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/expense_category.dart';
import 'report_exports.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late DateTimeRange _range;
  String _type = 'all'; // all | expense | income
  String? _catId; // null = all
  String? _accountId; // null = all
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _range,
    );
    if (picked != null && mounted) setState(() => _range = picked);
  }

  List<Expense> _filter(List<Expense> all) {
    final start =
        DateTime(_range.start.year, _range.start.month, _range.start.day);
    final end = DateTime(_range.end.year, _range.end.month, _range.end.day)
        .add(const Duration(days: 1));
    return all.where((e) {
      if (e.spentAt.isBefore(start) || !e.spentAt.isBefore(end)) return false;
      if (_type == 'expense' && !e.isExpense) return false;
      if (_type == 'income' && !e.isIncome) return false;
      if (_catId != null && e.categoryId != _catId) return false;
      if (_accountId != null && e.accountId != _accountId) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.spentAt.compareTo(a.spentAt));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = ref.watch(expensesProvider).asData?.value ?? const <Expense>[];
    final cats =
        ref.watch(categoriesProvider).asData?.value ?? const <ExpenseCategory>[];
    final accounts =
        ref.watch(accountsProvider).asData?.value ?? const <Account>[];
    final catMap = {for (final c in cats) c.id: c};

    final filtered = _filter(all);
    final spent =
        filtered.where((e) => e.isExpense).fold<double>(0, (s, e) => s + e.amount);
    final income =
        filtered.where((e) => e.isIncome).fold<double>(0, (s, e) => s + e.amount);
    final title = 'Expense report · ${formatDay(_range.start)}'
        ' – ${formatDay(_range.end)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.sm, AppSpace.lg, 32),
        children: [
          // ---- Filters ----
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date range', style: theme.textTheme.labelLarge),
                const SizedBox(height: AppSpace.sm),
                InkWell(
                  onTap: _pickRange,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.md, vertical: AppSpace.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.date_range_rounded,
                            size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: AppSpace.sm),
                        Expanded(
                          child: Text(
                              '${formatDay(_range.start)} — ${formatDay(_range.end)}',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        Text('Change',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.primary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                Text('Type', style: theme.textTheme.labelLarge),
                const SizedBox(height: AppSpace.sm),
                GlassSegmented(
                  labels: const ['All', 'Expense', 'Income'],
                  selected: const ['all', 'expense', 'income'].indexOf(_type),
                  onChanged: (i) => setState(
                      () => _type = const ['all', 'expense', 'income'][i]),
                ),
                const SizedBox(height: AppSpace.lg),
                Text('Category', style: theme.textTheme.labelLarge),
                const SizedBox(height: AppSpace.sm),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _catId == null,
                      onSelected: (_) => setState(() => _catId = null),
                    ),
                    for (final c in cats)
                      ChoiceChip(
                        label: Text('${c.icon} ${c.name}'),
                        selected: _catId == c.id,
                        onSelected: (_) => setState(() => _catId = c.id),
                      ),
                  ],
                ),
                if (accounts.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.lg),
                  Text('Account', style: theme.textTheme.labelLarge),
                  const SizedBox(height: AppSpace.sm),
                  Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.sm,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _accountId == null,
                        onSelected: (_) => setState(() => _accountId = null),
                      ),
                      for (final a in accounts)
                        ChoiceChip(
                          label: Text('${a.icon} ${a.name}'),
                          selected: _accountId == a.id,
                          onSelected: (_) => setState(() => _accountId = a.id),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          // ---- Summary ----
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${filtered.length} transactions',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
                const SizedBox(height: AppSpace.md),
                Row(
                  children: [
                    _sum(theme, 'Spent', spent, kSpend),
                    _sum(theme, 'Income', income, kIncome),
                    _sum(theme, 'Net', income - spent,
                        income - spent >= 0 ? kIncome : kSpend),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Text('Download', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              _exportBtn(theme, Icons.grid_on_rounded, 'CSV',
                  filtered.isEmpty || _busy
                      ? null
                      : () => _run(() => exportCsvReport(
                          context, filtered, catMap,
                          title: title))),
              const SizedBox(width: AppSpace.md),
              _exportBtn(theme, Icons.table_chart_rounded, 'Excel',
                  filtered.isEmpty || _busy
                      ? null
                      : () => _run(() => exportExcelReport(
                          context, filtered, catMap,
                          title: title))),
              const SizedBox(width: AppSpace.md),
              _exportBtn(theme, Icons.picture_as_pdf_rounded, 'PDF',
                  filtered.isEmpty || _busy
                      ? null
                      : () => _run(() => exportPdfReport(
                          context, filtered, catMap,
                          title: title,
                          range: _range,
                          spent: spent,
                          income: income))),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          // ---- Preview ----
          if (filtered.isNotEmpty) ...[
            Text('Preview', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpace.sm),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
              child: Column(
                children: [
                  for (final e in filtered.take(30))
                    ListTile(
                      dense: true,
                      leading: Text(catMap[e.categoryId]?.icon ?? '•',
                          style: const TextStyle(fontSize: 18)),
                      title: Text(
                          e.note.isEmpty
                              ? (catMap[e.categoryId]?.name ?? 'Other')
                              : e.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text(formatDay(e.spentAt)),
                      trailing: Text(
                        '${e.isIncome ? '+' : '-'}${formatMoney(e.amount)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: e.isIncome ? kIncome : null),
                      ),
                    ),
                  if (filtered.length > 30)
                    Padding(
                      padding: const EdgeInsets.all(AppSpace.sm),
                      child: Text('+ ${filtered.length - 30} more in the file',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sum(ThemeData theme, String label, double value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: theme.textTheme.bodySmall?.copyWith(
                  color: color, fontWeight: FontWeight.w700, fontSize: 10)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(formatMoney(value),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _exportBtn(
      ThemeData theme, IconData icon, String label, VoidCallback? onTap) {
    return Expanded(
      child: FilledButton.tonalIcon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14)),
      ),
    );
  }
}
