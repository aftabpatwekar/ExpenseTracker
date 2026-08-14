import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/glass.dart';
import '../../core/hex.dart';
import '../../data/category_repository.dart';
import '../../domain/models/expense_category.dart';

const List<String> _palette = [
  '#2a78d6', '#eb6834', '#1baf7a', '#eda100',
  '#e87ba4', '#008300', '#4a3aa7', '#e34948',
];

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cats = ref.watch(categoriesProvider);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Categories'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add category',
              onPressed: () => _openSheet(context, null),
            ),
          ],
        ),
        body: cats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load: $e')),
          data: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              for (final c in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    onTap: () => _openSheet(context, c),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: hexColor(c.color).withAlpha(45),
                              borderRadius: BorderRadius.circular(12)),
                          child: Center(
                              child: Text(c.icon,
                                  style: const TextStyle(fontSize: 18))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name,
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              Text(
                                c.keywords.isEmpty
                                    ? 'No keywords'
                                    : c.keywords.take(5).join(', ') +
                                        (c.keywords.length > 5 ? '…' : ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: theme.colorScheme.outline),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_outlined, size: 18),
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

  Future<void> _openSheet(BuildContext context, ExpenseCategory? cat) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _CategoryEditSheet(category: cat),
    );
  }
}

class _CategoryEditSheet extends ConsumerStatefulWidget {
  final ExpenseCategory? category;
  const _CategoryEditSheet({this.category});

  @override
  ConsumerState<_CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends ConsumerState<_CategoryEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _icon;
  late final TextEditingController _keywords;
  late String _color;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    _name = TextEditingController(text: c?.name ?? '');
    _icon = TextEditingController(text: c?.icon ?? '🏷️');
    _keywords = TextEditingController(text: c?.keywords.join(', ') ?? '');
    _color = c?.color ?? _palette.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _icon.dispose();
    _keywords.dispose();
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
    final kws = _keywords.text
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();
    try {
      await ref.read(categoryRepositoryProvider).upsert(
            id: widget.category?.id,
            name: name,
            icon: _icon.text.trim().isEmpty ? '🏷️' : _icon.text.trim(),
            color: _color,
            keywords: kws,
          );
      ref.invalidate(categoriesProvider);
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

  Future<void> _delete() async {
    final id = widget.category?.id;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete category?'),
        content: const Text('Expenses in it will become uncategorized.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(categoryRepositoryProvider).delete(id);
      ref.invalidate(categoriesProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not delete.');
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
            Text(widget.category == null ? 'New category' : 'Edit category',
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
              controller: _keywords,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Keywords (comma separated)',
                hintText: 'uber, ola, taxi, petrol',
                border: OutlineInputBorder(),
              ),
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
            if (widget.category != null) ...[
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
