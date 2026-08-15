import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../data/account_repository.dart';
import '../../data/category_repository.dart';
import '../../data/expense_repository.dart';
import '../../data/recurring_repository.dart';
import '../../domain/models/account.dart';
import '../../domain/models/expense_category.dart';
import '../../domain/models/recurring.dart';

const _freqs = ['daily', 'weekly', 'monthly'];
String _freqLabel(String f) => '${f[0].toUpperCase()}${f.substring(1)}';

class ScheduledScreen extends ConsumerWidget {
  const ScheduledScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rules = ref.watch(recurringProvider);
    final cats =
        ref.watch(categoriesProvider).asData?.value ?? const <ExpenseCategory>[];
    final catMap = {for (final c in cats) c.id: c};

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Scheduled'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add scheduled',
              onPressed: () => _edit(context, null),
            ),
          ],
        ),
        body: rules.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load: $e')),
          data: (list) => list.isEmpty
              ? Center(
                  child: Text('No scheduled transactions.\nTap ＋ to add one.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline)),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    for (final r in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          onTap: () => _edit(context, r),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        r.note.isEmpty
                                            ? (catMap[r.categoryId]?.name ??
                                                'Scheduled')
                                            : r.note,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.w700)),
                                    Text(
                                        '${_freqLabel(r.frequency)} · next ${formatDay(r.nextRun)}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                                color:
                                                    theme.colorScheme.outline)),
                                  ],
                                ),
                              ),
                              Text(
                                  '${r.type == 'income' ? '+' : ''}${formatMoney(r.amount)}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: r.type == 'income'
                                          ? const Color(0xFF1FB56B)
                                          : null)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, Recurring? r) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _RecurringEditSheet(rule: r),
    );
  }
}

class _RecurringEditSheet extends ConsumerStatefulWidget {
  final Recurring? rule;
  const _RecurringEditSheet({this.rule});

  @override
  ConsumerState<_RecurringEditSheet> createState() =>
      _RecurringEditSheetState();
}

class _RecurringEditSheetState extends ConsumerState<_RecurringEditSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late String _type;
  late String _frequency;
  late DateTime _nextRun;
  String? _categoryId;
  String? _accountId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    _amount =
        TextEditingController(text: r == null ? '' : trimAmount(r.amount));
    _note = TextEditingController(text: r?.note ?? '');
    _type = r?.type ?? 'expense';
    _frequency = r?.frequency ?? 'monthly';
    _nextRun = r?.nextRun ?? DateTime.now();
    _categoryId = r?.categoryId;
    _accountId = r?.accountId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _nextRun,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) setState(() => _nextRun = d);
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amount.text.trim()) ?? 0;
    if (amt <= 0) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(recurringRepositoryProvider).upsert(
            id: widget.rule?.id,
            amount: amt,
            type: _type,
            categoryId: _categoryId,
            accountId: _accountId,
            note: _note.text.trim(),
            frequency: _frequency,
            nextRun: _nextRun,
          );
      ref.invalidate(recurringProvider);
      ref.invalidate(expensesProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save.';
        });
      }
    }
  }

  Future<void> _delete() async {
    final id = widget.rule?.id;
    if (id == null) return;
    try {
      await ref.read(recurringRepositoryProvider).delete(id);
      ref.invalidate(recurringProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not delete.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cats =
        ref.watch(categoriesProvider).asData?.value ?? const <ExpenseCategory>[];
    final accounts =
        ref.watch(accountsProvider).asData?.value ?? const <Account>[];
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.rule == null ? 'New scheduled' : 'Edit scheduled',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Expense')),
                ButtonSegment(value: 'income', label: Text('Income')),
              ],
              selected: {_type},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '₹ ',
                        border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event, size: 18),
                    label: Text('From ${formatDay(_nextRun)}',
                        overflow: TextOverflow.ellipsis),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                  labelText: 'Note', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Align(
                alignment: Alignment.centerLeft,
                child: Text('Repeat', style: theme.textTheme.labelLarge)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final f in _freqs)
                  ChoiceChip(
                    label: Text(_freqLabel(f)),
                    selected: _frequency == f,
                    onSelected: (_) => setState(() => _frequency = f),
                  ),
              ],
            ),
            if (cats.isNotEmpty) ...[
              const SizedBox(height: 16),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Category', style: theme.textTheme.labelLarge)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in cats)
                    ChoiceChip(
                      label: Text('${c.icon} ${c.name}'),
                      selected: c.id == _categoryId,
                      onSelected: (_) => setState(() => _categoryId = c.id),
                    ),
                ],
              ),
            ],
            if (accounts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Account', style: theme.textTheme.labelLarge)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in accounts)
                    ChoiceChip(
                      label: Text('${a.icon} ${a.name}'),
                      selected: a.id == _accountId,
                      onSelected: (_) => setState(() => _accountId = a.id),
                    ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
            if (widget.rule != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                label: const Text('Delete',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
