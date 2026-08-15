import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/expense_repository.dart';
import '../../data/receipt_repository.dart';
import '../../domain/models/expense.dart';

/// Tap a transaction → this sheet. Delete is a *soft* delete with an Undo.
Future<void> showExpenseActions(BuildContext context, Expense expense) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _ExpenseActionsSheet(expense: expense),
  );
}

class _ExpenseActionsSheet extends ConsumerWidget {
  final Expense expense;
  const _ExpenseActionsSheet({required this.expense});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(expense.note.isEmpty ? 'Expense' : expense.note,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${formatMoney(expense.amount)} · ${formatDay(expense.spentAt)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
            if (expense.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in expense.tags)
                    Chip(
                      label: Text(t),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ],
            if (expense.receiptUrl != null) ...[
              const SizedBox(height: 16),
              _ReceiptPreview(path: expense.receiptUrl!),
            ],
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.errorContainer,
                foregroundColor: theme.colorScheme.onErrorContainer,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(context);
                final repo = ref.read(expenseRepositoryProvider);
                await repo.softDelete(expense.id);
                ref.invalidate(expensesProvider);
                nav.pop();
                messenger.showSnackBar(SnackBar(
                  content: const Text('Expense deleted'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () async {
                      await repo.restore(expense.id);
                      ref.invalidate(expensesProvider);
                    },
                  ),
                ));
              },
            ),
            const SizedBox(height: 8),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
          ],
        ),
      ),
    );
  }
}

/// Shows a receipt thumbnail (via a signed URL); tap to view full-screen.
class _ReceiptPreview extends ConsumerWidget {
  final String path;
  const _ReceiptPreview({required this.path});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final urlFuture = ref.read(receiptRepositoryProvider).signedUrl(path);
    return FutureBuilder<String>(
      future: urlFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
              height: 140, child: Center(child: CircularProgressIndicator()));
        }
        if (!snap.hasData) {
          return Text('Receipt unavailable',
              style: TextStyle(color: theme.colorScheme.outline));
        }
        final url = snap.data!;
        return GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _ReceiptViewer(url: url),
          )),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 160,
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Center(child: Icon(Icons.broken_image_outlined)),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReceiptViewer extends StatelessWidget {
  final String url;
  const _ReceiptViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(url),
        ),
      ),
    );
  }
}
