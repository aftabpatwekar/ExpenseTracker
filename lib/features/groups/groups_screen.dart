import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../data/group_repository.dart';
import '../../domain/models/group.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New group'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
              labelText: 'Group name', hintText: 'e.g. Flatmates'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(groupRepositoryProvider).createGroup(name.trim());
      ref.invalidate(groupsProvider);
    } catch (_) {
      messenger
          .showSnackBar(const SnackBar(content: Text('Could not create group')));
    }
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join a group'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
              labelText: 'Invite code', hintText: '6-character code'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Join')),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(groupRepositoryProvider).joinGroup(code.trim());
      ref.invalidate(groupsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Joined the group')));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Invalid or expired invite code')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Groups')),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load groups.\n$e')),
        data: (groups) => ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.lg, AppSpace.sm, AppSpace.lg, 32),
          children: [
            Text(
                'Track a shared budget together. Create a group and share its '
                'invite code, or join one.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: AppSpace.lg),
            if (groups.isEmpty)
              _EmptyGroups(theme: theme)
            else
              for (final g in groups) ...[
                _GroupTile(group: g),
                const SizedBox(height: AppSpace.md),
              ],
            const SizedBox(height: AppSpace.sm),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _create(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Create'),
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _join(context, ref),
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('Join'),
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyGroups extends StatelessWidget {
  final ThemeData theme;
  const _EmptyGroups({required this.theme});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          const SizedBox(height: AppSpace.sm),
          Icon(Icons.groups_2_outlined,
              size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpace.md),
          Text('No groups yet',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpace.xs),
          Text('Create one below to start sharing a budget.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: AppSpace.sm),
        ],
      ),
    );
  }
}

class _GroupTile extends ConsumerWidget {
  final Group group;
  const _GroupTile({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final members = ref.watch(groupMembersProvider(group.id)).asData?.value;
    return GlassCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg, vertical: AppSpace.md),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => GroupDetailScreen(group: group))),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
                gradient: kAccentGradient, shape: BoxShape.circle),
            child: const Icon(Icons.groups_2_rounded, color: Colors.white),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                    members == null
                        ? 'Tap to open'
                        : '${members.length} member${members.length == 1 ? '' : 's'} · code ${group.inviteCode}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
