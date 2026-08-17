import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../data/category_repository.dart';
import '../../data/group_repository.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/expense_category.dart';
import '../../domain/models/group.dart';
import '../entry/add_expense_sheet.dart';

class GroupDetailScreen extends ConsumerWidget {
  final Group group;
  const GroupDetailScreen({super.key, required this.group});

  Future<void> _setBudget(
      BuildContext context, WidgetRef ref, double? current) async {
    final ctrl = TextEditingController(
        text: current == null ? '' : trimAmount(current));
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Monthly group budget'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
          onSubmitted: (v) =>
              Navigator.pop(ctx, double.tryParse(v.trim())),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, double.tryParse(ctrl.text.trim())),
              child: const Text('Save')),
        ],
      ),
    );
    if (value == null || value < 0) return;
    await ref.read(groupRepositoryProvider).setMonthlyBudget(group.id, value);
    ref.invalidate(groupBudgetProvider(group.id));
  }

  Future<void> _addShared(BuildContext context, WidgetRef ref) async {
    await showAddExpenseSheet(context, groupId: group.id);
    ref.invalidate(groupExpensesProvider(group.id));
    ref.invalidate(groupBudgetProvider(group.id));
  }

  Future<void> _confirmLeaveOrDelete(
      BuildContext context, WidgetRef ref, bool isOwner) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isOwner ? 'Delete group?' : 'Leave group?'),
        content: Text(isOwner
            ? 'This removes the group and its shared budget for everyone. '
                'Shared expenses become personal to whoever added them.'
            : 'You will stop seeing this group\'s shared budget and expenses.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isOwner ? 'Delete' : 'Leave')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final repo = ref.read(groupRepositoryProvider);
    final nav = Navigator.of(context);
    if (isOwner) {
      await repo.deleteGroup(group.id);
    } else {
      await repo.leaveGroup(group.id);
    }
    ref.invalidate(groupsProvider);
    nav.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = group.ownerId == uid;
    final members =
        ref.watch(groupMembersProvider(group.id)).asData?.value ?? const [];
    final expenses =
        ref.watch(groupExpensesProvider(group.id)).asData?.value ??
            const <Expense>[];
    final budget = ref.watch(groupBudgetProvider(group.id)).asData?.value;
    final cats =
        ref.watch(categoriesProvider).asData?.value ?? const <ExpenseCategory>[];
    final catMap = {for (final c in cats) c.id: c};

    final now = DateTime.now();
    final monthSpend = expenses
        .where((e) =>
            e.isExpense &&
            e.spentAt.year == now.year &&
            e.spentAt.month == now.month)
        .fold<double>(0, (s, e) => s + e.amount);

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          IconButton(
            tooltip: isOwner ? 'Delete group' : 'Leave group',
            icon: Icon(isOwner ? Icons.delete_outline : Icons.logout),
            onPressed: () => _confirmLeaveOrDelete(context, ref, isOwner),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addShared(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add shared'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(groupExpensesProvider(group.id));
          ref.invalidate(groupBudgetProvider(group.id));
          ref.invalidate(groupMembersProvider(group.id));
          await ref.read(groupExpensesProvider(group.id).future);
        },
        child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.sm, AppSpace.lg, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // ---- Budget ----
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('This month', style: theme.textTheme.titleMedium),
                    ),
                    TextButton(
                      onPressed: () => _setBudget(context, ref, budget),
                      child: Text(budget == null ? 'Set budget' : 'Edit'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                Text(formatMoney(monthSpend),
                    style: theme.textTheme.headlineSmall),
                if (budget != null) ...[
                  Text('of ${formatMoney(budget)} budget',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                  const SizedBox(height: AppSpace.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: budget > 0
                          ? (monthSpend / budget).clamp(0, 1).toDouble()
                          : 0,
                      minHeight: 10,
                      backgroundColor: theme.colorScheme.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation(
                          monthSpend > budget ? kSpend : theme.colorScheme.primary),
                    ),
                  ),
                  if (monthSpend > budget)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.sm),
                      child: Text(
                          'Over budget by ${formatMoney(monthSpend - budget)}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: kSpend)),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          // ---- Invite ----
          GlassCard(
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invite code', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 2),
                    Text(group.inviteCode,
                        style: theme.textTheme.headlineSmall?.copyWith(
                            letterSpacing: 3, fontWeight: FontWeight.w800)),
                  ],
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: group.inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied')));
                  },
                ),
                IconButton(
                  tooltip: 'Share',
                  icon: const Icon(Icons.ios_share_rounded),
                  onPressed: () => SharePlus.instance.share(ShareParams(
                      text: 'Join my "${group.name}" expense group. '
                          'Open Expense Tracker → Groups → Join, and enter code: '
                          '${group.inviteCode}')),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          // ---- Members ----
          Text('Members (${members.length})',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpace.sm),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
            child: Column(
              children: [
                for (final m in members)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                          (m.name?.isNotEmpty == true
                                  ? m.name![0]
                                  : '?')
                              .toUpperCase(),
                          style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(m.name ?? 'Member'),
                    trailing: m.isOwner
                        ? Chip(
                            label: const Text('Owner'),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          )
                        : null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          // ---- Shared expenses ----
          Text('Shared expenses', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpace.sm),
          if (expenses.isEmpty)
            GlassCard(
              child: Text('No shared expenses yet. Tap “Add shared” to log one.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline)),
            )
          else
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
              child: Column(
                children: [
                  for (final e in expenses.take(50))
                    ListTile(
                      leading: Text(catMap[e.categoryId]?.icon ?? '•',
                          style: const TextStyle(fontSize: 18)),
                      title: Text(
                          e.note.isEmpty
                              ? (catMap[e.categoryId]?.name ?? 'Other')
                              : e.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text(formatDay(e.spentAt)),
                      trailing: Text(formatMoney(e.amount),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
        ],
        ),
      ),
    );
  }
}
