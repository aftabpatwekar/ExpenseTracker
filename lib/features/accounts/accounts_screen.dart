import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/hex.dart';
import '../../core/theme.dart';
import '../../data/account_repository.dart';
import '../../data/expense_repository.dart';
import '../../domain/models/account.dart';
import '../../domain/models/expense.dart';

const List<String> _palette = [
  '#1baf7a', '#2a78d6', '#eb6834', '#eda100',
  '#e87ba4', '#4a3aa7', '#008300', '#e34948',
];
const List<String> _types = ['cash', 'bank', 'card', 'wallet', 'other'];

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accounts =
        ref.watch(accountsProvider).asData?.value ?? const <Account>[];
    final expenses =
        ref.watch(expensesProvider).asData?.value ?? const <Expense>[];
    final total =
        accounts.fold<double>(0, (s, a) => s + accountBalance(a, expenses));

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          GlassHeader(
            title: 'Accounts',
            trailing: IconButton.filledTonal(
              onPressed: () => _edit(context, null),
              icon: const Icon(Icons.add),
              tooltip: 'Add account',
            ),
          ),
          const SizedBox(height: 12),
          Container(
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
                const Text('Total balance',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(formatMoney(total),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('Add your first account',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline)),
              ),
            )
          else
            for (final a in accounts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  onTap: () => _edit(context, a),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: hexColor(a.color).withAlpha(45),
                            borderRadius: BorderRadius.circular(12)),
                        child: Center(
                            child: Text(a.icon,
                                style: const TextStyle(fontSize: 20))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.name,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            Text(a.type[0].toUpperCase() + a.type.substring(1),
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline)),
                          ],
                        ),
                      ),
                      Builder(builder: (_) {
                        final bal = accountBalance(a, expenses);
                        return Text(formatMoney(bal),
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: bal < 0 ? const Color(0xFFE05353) : null));
                      }),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, Account? account) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _AccountEditSheet(account: account),
    );
  }
}

class _AccountEditSheet extends ConsumerStatefulWidget {
  final Account? account;
  const _AccountEditSheet({this.account});

  @override
  ConsumerState<_AccountEditSheet> createState() => _AccountEditSheetState();
}

class _AccountEditSheetState extends ConsumerState<_AccountEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _icon;
  late final TextEditingController _opening;
  late String _type;
  late String _color;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _name = TextEditingController(text: a?.name ?? '');
    _icon = TextEditingController(text: a?.icon ?? '💵');
    _opening = TextEditingController(
        text: (a == null || a.openingBalance == 0)
            ? ''
            : trimAmount(a.openingBalance));
    _type = a?.type ?? 'cash';
    _color = a?.color ?? _palette.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _icon.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(accountRepositoryProvider).upsert(
            id: widget.account?.id,
            name: name,
            type: _type,
            icon: _icon.text.trim().isEmpty ? '💵' : _icon.text.trim(),
            color: _color,
            openingBalance: double.tryParse(_opening.text.trim()) ?? 0,
          );
      ref.invalidate(accountsProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save (that name may already exist).';
        });
      }
    }
  }

  Future<void> _archive() async {
    final id = widget.account?.id;
    if (id == null) return;
    try {
      await ref.read(accountRepositoryProvider).archive(id);
      ref.invalidate(accountsProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not remove.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.account == null ? 'New account' : 'Edit account',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 64,
                  child: TextField(
                    controller: _icon,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22),
                    decoration: const InputDecoration(labelText: 'Icon'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                        labelText: 'Name', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _opening,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Opening balance',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Align(
                alignment: Alignment.centerLeft,
                child: Text('Type', style: theme.textTheme.labelLarge)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final t in _types)
                  ChoiceChip(
                    label: Text(t[0].toUpperCase() + t.substring(1)),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
                alignment: Alignment.centerLeft,
                child: Text('Colour', style: theme.textTheme.labelLarge)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final hex in _palette)
                  GestureDetector(
                    onTap: () => setState(() => _color = hex),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: hexColor(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _color == hex
                                ? Colors.white
                                : Colors.transparent,
                            width: 3),
                      ),
                    ),
                  ),
              ],
            ),
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
            if (widget.account != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _archive,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                label: const Text('Remove',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
