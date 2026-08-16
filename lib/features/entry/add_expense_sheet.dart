import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/format.dart';
import '../../data/account_repository.dart';
import '../../data/category_repository.dart';
import '../../data/expense_repository.dart';
import '../../data/group_repository.dart';
import '../../data/receipt_repository.dart';
import '../../data/transcription_service.dart';
import '../../domain/models/group.dart';
import '../../domain/models/account.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/expense_category.dart';
import '../../domain/services/expense_parser.dart';

Future<void> showAddExpenseSheet(BuildContext context,
    {bool startVoice = false,
    String? groupId,
    Expense? initial,
    bool edit = false}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => AddExpenseSheet(
        startVoice: startVoice, groupId: groupId, initial: initial, edit: edit),
  );
}

/// Opens the sheet to edit an existing expense.
Future<void> showEditExpenseSheet(BuildContext context, Expense e) =>
    showAddExpenseSheet(context, initial: e, edit: true);

/// Opens the sheet pre-filled from an expense, but saves as a new entry.
Future<void> showDuplicateExpenseSheet(BuildContext context, Expense e) =>
    showAddExpenseSheet(context, initial: e, edit: false);

class AddExpenseSheet extends ConsumerStatefulWidget {
  /// When true, the sheet starts listening immediately (used by the
  /// Back-Tap / quick-add entry point).
  final bool startVoice;

  /// When set, the expense is created straight into this group (selector hidden).
  final String? groupId;

  /// Pre-fill the form from this expense (for edit or duplicate).
  final Expense? initial;

  /// When true with [initial], saving updates that expense instead of adding.
  final bool edit;
  const AddExpenseSheet(
      {super.key,
      this.startVoice = false,
      this.groupId,
      this.initial,
      this.edit = false});

  @override
  ConsumerState<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<AddExpenseSheet> {
  final _quick = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _tagInput = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  final AudioRecorder _recorder = AudioRecorder(); // web voice (record → cloud)
  bool _recording = false;
  bool _transcribing = false;
  Timer? _recordTimer; // auto-stop safety

  final List<String> _tags = [];
  String? _categoryId;
  String _type = 'expense';
  String? _accountId;
  DateTime _date = DateTime.now();
  bool _saving = false;
  bool _listening = false;
  bool _speechReady = false;
  bool _speechInitTried = false;
  String? _error;
  String? _receiptPath; // storage path once a receipt is uploaded
  bool _uploadingReceipt = false;
  String? _groupId; // when set, expense is shared with this group

  @override
  void initState() {
    super.initState();
    _groupId = widget.groupId;
    // Pre-fill for edit / duplicate.
    final init = widget.initial;
    if (init != null) {
      _amount.text = trimAmount(init.amount);
      _note.text = init.note;
      _categoryId = init.categoryId;
      _type = init.type;
      _accountId = init.accountId;
      _tags.addAll(init.tags);
      _date = init.spentAt;
      _receiptPath = init.receiptUrl;
      _groupId = widget.groupId ?? init.groupId;
    }
    // Opened via the mic button / Back-Tap → start capturing immediately.
    if (widget.startVoice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (kIsWeb) {
          // Don't await before getUserMedia — the browser needs the tap's
          // activation to still be live. Categories are already cached here.
          final cats = ref.read(categoriesProvider).asData?.value ??
              const <ExpenseCategory>[];
          _toggleWebVoice(cats);
        } else {
          ref.read(categoriesProvider.future).then((cats) {
            if (mounted) _toggleListen(cats);
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    _recordTimer?.cancel();
    _recorder.dispose();
    _quick.dispose();
    _amount.dispose();
    _note.dispose();
    _tagInput.dispose();
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

  /// Web voice: record audio in the browser → send to the transcribe Edge
  /// Function → parse. Works where the browser has no speech API (iOS Safari).
  Future<void> _toggleWebVoice(List<ExpenseCategory> cats) async {
    if (_transcribing) return;
    if (_recording) {
      _recordTimer?.cancel();
      setState(() {
        _recording = false;
        _transcribing = true;
      });
      try {
        final path = await _recorder.stop();
        if (path == null) {
          if (mounted) setState(() => _transcribing = false);
          return;
        }
        // On web, `path` is a blob: URL — fetch its bytes and MIME type.
        final blob = await http.get(Uri.parse(path));
        final ct = blob.headers['content-type'] ?? 'audio/webm';
        final text = await ref
            .read(transcriptionServiceProvider)
            .transcribe(blob.bodyBytes, contentType: ct);
        if (!mounted) return;
        if (text.isNotEmpty) {
          _quick.text = text;
          _onQuickChanged(text, cats);
        } else {
          setState(() => _error = "Didn't catch that — try again or type it.");
        }
      } catch (_) {
        if (mounted) {
          setState(() =>
              _error = 'Voice unavailable. Type it, or check the setup.');
        }
      } finally {
        if (mounted) setState(() => _transcribing = false);
      }
      return;
    }
    // Start recording. Pick an encoder the browser's MediaRecorder supports
    // (Chrome: Opus/webm; Safari: AAC/mp4) — the default AAC fails on Chrome.
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          setState(() => _error = 'Microphone permission is needed for voice.');
        }
        return;
      }
      final encoder = await _recorder.isEncoderSupported(AudioEncoder.opus)
          ? AudioEncoder.opus
          : await _recorder.isEncoderSupported(AudioEncoder.aacLc)
              ? AudioEncoder.aacLc
              : AudioEncoder.wav;
      await _recorder.start(RecordConfig(encoder: encoder), path: 'molbhav');
      if (mounted) {
        setState(() {
          _recording = true;
          _error = null;
        });
        // Safety: auto-stop + transcribe after 20s so it never runs away.
        _recordTimer?.cancel();
        _recordTimer = Timer(const Duration(seconds: 20), () {
          if (_recording && mounted) _toggleWebVoice(cats);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not start the mic: $e');
    }
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
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_date));
    setState(() => _date = DateTime(d.year, d.month, d.day,
        t?.hour ?? _date.hour, t?.minute ?? _date.minute));
  }

  void _addTag(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return;
    setState(() {
      if (!_tags.contains(t)) _tags.add(t);
      _tagInput.clear();
    });
  }

  Future<void> _pickReceipt() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker()
        .pickImage(source: source, imageQuality: 60, maxWidth: 1600);
    if (picked == null) return;
    setState(() {
      _uploadingReceipt = true;
      _error = null;
    });
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final path =
          await ref.read(receiptRepositoryProvider).upload(bytes, ext: ext);
      if (mounted) {
        setState(() {
          _receiptPath = path;
          _uploadingReceipt = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _uploadingReceipt = false;
          _error = 'Could not upload the receipt. Check your connection.';
        });
      }
    }
  }

  Future<void> _save(List<ExpenseCategory> cats, String? accountId) async {
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
      final repo = ref.read(expenseRepositoryProvider);
      if (widget.edit && widget.initial != null) {
        await repo.update(
          widget.initial!.id,
          amount: amt,
          categoryId: _categoryId ?? _fallbackId(cats),
          note: _note.text.trim(),
          spentAt: _date,
          type: _type,
          accountId: accountId,
          tags: _tags,
          receiptUrl: _receiptPath,
          groupId: _groupId,
        );
      } else {
        await repo.add(
          amount: amt,
          categoryId: _categoryId ?? _fallbackId(cats),
          note: _note.text.trim(),
          rawText: _quick.text.trim().isEmpty ? null : _quick.text.trim(),
          spentAt: _date,
          type: _type,
          accountId: accountId,
          tags: _tags,
          receiptUrl: _receiptPath,
          groupId: _groupId,
        );
      }
      ref.invalidate(expensesProvider);
      final origGroup = widget.initial?.groupId;
      if (origGroup != null && origGroup != _groupId) {
        ref.invalidate(groupExpensesProvider(origGroup));
        ref.invalidate(groupBudgetProvider(origGroup));
      }
      if (_groupId != null) {
        ref.invalidate(groupExpensesProvider(_groupId!));
        ref.invalidate(groupBudgetProvider(_groupId!));
      }
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
    final accounts =
        ref.watch(accountsProvider).asData?.value ?? const <Account>[];
    final selectedAccount =
        _accountId ?? (accounts.isNotEmpty ? accounts.first.id : null);
    final allTags = <String>{
      for (final e
          in ref.watch(expensesProvider).asData?.value ?? const <Expense>[])
        ...e.tags
    }.toList();
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
              Text(
                  '${widget.edit ? 'Edit' : 'Add'} '
                  '${_type == 'income' ? 'income' : 'expense'}',
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
              Builder(builder: (context) {
                final active = kIsWeb ? _recording : _listening;
                final hint = _transcribing
                    ? 'Transcribing…'
                    : active
                        ? (kIsWeb
                            ? 'Recording… tap ⏹ when done'
                            : 'Listening… say “250 groceries veggies”')
                        : 'Tap the mic and speak, or type naturally';
                return Text(
                  hint,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: (active || _transcribing)
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline),
                );
              }),
              const SizedBox(height: 16),
              TextField(
                controller: _quick,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (v) => _onQuickChanged(v, cats),
                decoration: InputDecoration(
                  hintText: '250 groceries weekly veggies',
                  prefixIcon: const Icon(Icons.bolt_outlined),
                  suffixIcon: _transcribing
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2)))
                      : IconButton(
                          icon: Icon((kIsWeb ? _recording : _listening)
                              ? Icons.stop_circle
                              : Icons.mic_none),
                          color: (kIsWeb ? _recording : _listening)
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                          tooltip: (kIsWeb ? _recording : _listening)
                              ? 'Stop'
                              : 'Speak',
                          onPressed: () => kIsWeb
                              ? _toggleWebVoice(cats)
                              : _toggleListen(cats),
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
                      label: Text(
                          '${formatDay(_date)} · ${TimeOfDay.fromDateTime(_date).format(context)}',
                          overflow: TextOverflow.ellipsis),
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
              if (accounts.isNotEmpty) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Account', style: theme.textTheme.labelLarge),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: accounts.map((a) {
                    return ChoiceChip(
                      label: Text('${a.icon} ${a.name}'),
                      selected: a.id == selectedAccount,
                      onSelected: (_) => setState(() => _accountId = a.id),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Tags', style: theme.textTheme.labelLarge),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _tagInput,
                textInputAction: TextInputAction.done,
                onSubmitted: _addTag,
                decoration: InputDecoration(
                  hintText: 'Add a tag (e.g. vacation)',
                  prefixIcon: const Icon(Icons.tag),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _addTag(_tagInput.text),
                  ),
                ),
              ),
              if (_tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in _tags)
                      InputChip(
                        label: Text(t),
                        onDeleted: () => setState(() => _tags.remove(t)),
                      ),
                  ],
                ),
              ],
              if (allTags.where((t) => !_tags.contains(t)).isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t
                        in allTags.where((x) => !_tags.contains(x)).take(8))
                      ActionChip(label: Text(t), onPressed: () => _addTag(t)),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Receipt', style: theme.textTheme.labelLarge),
              ),
              const SizedBox(height: 8),
              if (_receiptPath == null)
                OutlinedButton.icon(
                  onPressed: _uploadingReceipt ? null : _pickReceipt,
                  icon: _uploadingReceipt
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.attach_file),
                  label: Text(_uploadingReceipt
                      ? 'Uploading…'
                      : 'Attach a receipt photo'),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                )
              else
                Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Receipt attached')),
                    TextButton(
                      onPressed: () => setState(() => _receiptPath = null),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              // Optional group sharing.
              if (widget.groupId == null)
                Builder(builder: (context) {
                  final groups =
                      ref.watch(groupsProvider).asData?.value ?? const <Group>[];
                  if (groups.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Share with group',
                            style: theme.textTheme.labelLarge),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('None'),
                            selected: _groupId == null,
                            onSelected: (_) => setState(() => _groupId = null),
                          ),
                          for (final g in groups)
                            ChoiceChip(
                              label: Text(g.name),
                              selected: _groupId == g.id,
                              onSelected: (_) =>
                                  setState(() => _groupId = g.id),
                            ),
                        ],
                      ),
                    ],
                  );
                })
              else
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      Icon(Icons.groups_2_rounded,
                          size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Adding to a shared group',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline)),
                    ],
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : () => _save(cats, selectedAccount),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(widget.edit ? 'Save changes' : 'Save expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
