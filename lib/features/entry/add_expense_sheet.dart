import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/format.dart';
import '../../data/category_repository.dart';
import '../../data/expense_repository.dart';
import '../../domain/models/expense_category.dart';
import '../../domain/services/expense_parser.dart';

Future<void> showAddExpenseSheet(BuildContext context, {bool startVoice = false}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => AddExpenseSheet(startVoice: startVoice),
  );
}

class AddExpenseSheet extends ConsumerStatefulWidget {
  /// When true, the sheet starts listening immediately (used by the
  /// Back-Tap / quick-add entry point).
  final bool startVoice;
  const AddExpenseSheet({super.key, this.startVoice = false});

  @override
  ConsumerState<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<AddExpenseSheet> {
  final _quick = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final SpeechToText _speech = SpeechToText();

  String? _categoryId;
  String _type = 'expense';
  DateTime _date = DateTime.now();
  bool _saving = false;
  bool _listening = false;
  bool _speechReady = false;
  bool _speechInitTried = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Opened via Back-Tap / "Speak expense" → start listening immediately.
    if (widget.startVoice) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final cats = await ref.read(categoriesProvider.future);
        if (mounted) _toggleListen(cats);
      });
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    _quick.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  String _fallbackId(List<ExpenseCategory> cats) =>
      cats.firstWhere((c) => c.name == 'Other', orElse: () => cats.last).id;

  void _onQuickChanged(String v, List<ExpenseCategory> cats) {
    if (v.trim().isEmpty || cats.isEmpty) return;
    final parsed =
        ExpenseParser(cats, fallbackCategoryId: _fallbackId(cats)).parse(v);
    setState(() {
      if (parsed.amount > 0) _amount.text = trimAmount(parsed.amount);
      _note.text = parsed.note;
      _categoryId = parsed.categoryId;
    });
  }

  Future<void> _toggleListen(List<ExpenseCategory> cats) async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!_speechInitTried) {
      _speechInitTried = true;
      _speechReady = await _speech.initialize(
        onStatus: (s) {
          if ((s == 'done' || s == 'notListening') && mounted) {
            setState(() => _listening = false);
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _listening = false;
              _error = 'Voice unavailable: ${e.errorMsg}';
            });
          }
        },
      );
    }
    if (!_speechReady) {
      setState(() => _error =
          'Microphone/speech not available. Check the mic permission.');
      return;
    }
    setState(() {
      _listening = true;
      _error = null;
    });
    await _speech.listen(
      onResult: (r) {
        if (!mounted) return;
        _quick.text = r.recognizedWords;
        _quick.selection =
            TextSelection.collapsed(offset: _quick.text.length);
        _onQuickChanged(r.recognizedWords, cats);
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save(List<ExpenseCategory> cats) async {
    final amt = double.tryParse(_amount.text.trim()) ?? 0;
    if (amt <= 0) {
      setState(() => _error = 'Enter an amount greater than 0');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(expenseRepositoryProvider).add(
            amount: amt,
            categoryId: _categoryId ?? _fallbackId(cats),
            note: _note.text.trim(),
            rawText: _quick.text.trim().isEmpty ? null : _quick.text.trim(),
            spentAt: _date,
            type: _type,
          );
      ref.invalidate(expensesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catsAsync = ref.watch(categoriesProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
      child: catsAsync.when(
        loading: () => const SizedBox(
            height: 200, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => SizedBox(
            height: 160,
            child: Center(child: Text('Could not load categories.\n$e'))),
        data: (cats) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_type == 'income' ? 'Add income' : 'Add expense',
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
              const SizedBox(height: 8),
              Text(
                _listening
                    ? 'Listening… say something like “250 groceries veggies”'
                    : 'Tap the mic and speak, or type naturally',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: _listening
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _quick,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (v) => _onQuickChanged(v, cats),
                decoration: InputDecoration(
                  hintText: '250 groceries weekly veggies',
                  prefixIcon: const Icon(Icons.bolt_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_listening ? Icons.stop_circle : Icons.mic_none),
                    color: _listening
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                    tooltip: _listening ? 'Stop' : 'Speak',
                    onPressed: () => _toggleListen(cats),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(formatDay(_date)),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Category', style: theme.textTheme.labelLarge),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cats.map((c) {
                  final selected = c.id == _categoryId;
                  return ChoiceChip(
                    label: Text('${c.icon} ${c.name}'),
                    selected: selected,
                    onSelected: (_) => setState(() => _categoryId = c.id),
                  );
                }).toList(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : () => _save(cats),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
