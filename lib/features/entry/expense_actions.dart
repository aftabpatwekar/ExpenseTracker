import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/expense_repository.dart';
import '../../data/group_repository.dart';
import '../../data/receipt_repository.dart';
import '../../data/recurring_repository.dart';
import '../../domain/models/expense.dart';
import 'add_expense_sheet.dart';

/// Long-press a transaction → this menu: edit, duplicate, make recurring, delete.
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

  Future<void> _makeRecurring(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final nextRun = DateTime(now.year, now.month + 1, now.day);
    Navigator.pop(context);
    try {
      await ref.read(recurringRepositoryProvider).upsert(
            amount: expense.amount,
            type: expense.type,
            categoryId: expense.categoryId,
            accountId: expense.accountId,
            note: expense.note,
            frequency: 'monthly',
            nextRun: nextRun,
          );
      ref.invalidate(recurringProvider);
      messenger.showSnackBar(const SnackBar(
          content: Text('Added as a monthly recurring transaction')));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not create recurring rule')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(expense.note.isEmpty ? 'Transaction' : expense.note,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
                '${expense.isIncome ? '+' : ''}${formatMoney(expense.amount)}'
                ' · ${formatDay(expense.spentAt)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
            if (expense.tags.isNotEmpty) ...[
              const SizedBox(height: AppSpace.md),
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
              const SizedBox(height: AppSpace.md),
              _ReceiptPreview(path: expense.receiptUrl!),
            ],
            const SizedBox(height: AppSpace.md),
            const Divider(height: 1),
            _action(context, Icons.edit_outlined, 'Edit', () {
              Navigator.pop(context);
              showEditExpenseSheet(context, expense);
            }),
            _action(context, Icons.copy_all_outlined, 'Duplicate', () {
              Navigator.pop(context);
              showDuplicateExpenseSheet(context, expense);
            }),
            _action(context, Icons.event_repeat_outlined, 'Make recurring',
                () => _makeRecurring(context, ref)),
            _action(context, Icons.delete_outline, 'Delete', () async {
              final messenger = ScaffoldMessenger.of(context);
              final repo = ref.read(expenseRepositoryProvider);
              Navigator.pop(context);
              await repo.softDelete(expense.id);
              ref.invalidate(expensesProvider);
              if (expense.groupId != null) {
                ref.invalidate(groupExpensesProvider(expense.groupId!));
                ref.invalidate(groupBudgetProvider(expense.groupId!));
              }
              messenger.showSnackBar(SnackBar(
                content: const Text('Transaction deleted'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () async {
                    await repo.restore(expense.id);
                    ref.invalidate(expensesProvider);
                  },
                ),
              ));
            }, danger: true),
          ],
        ),
      ),
    );
  }

  Widget _action(BuildContext context, IconData icon, String label,
      VoidCallback onTap,
      {bool danger = false}) {
    final theme = Theme.of(context);
    final color = danger ? theme.colorScheme.error : null;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
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
