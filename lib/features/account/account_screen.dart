import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_prefs.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../auth/auth_repository.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final email = ref.watch(authRepositoryProvider).currentUser?.email ?? 'you';
    final mode = ref.watch(themeModeProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Account',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          GlassCard(
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                      gradient: kAccentGradient, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      email.isNotEmpty ? email[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Signed in as',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline)),
                      Text(email,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _tile(context, Icons.currency_rupee, 'Currency', '₹ INR'),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.brightness_6_outlined),
                  title: const Text('Theme'),
                  trailing: Text(themeModeLabel(mode),
                      style: TextStyle(color: theme.colorScheme.outline)),
                  onTap: () => _pickTheme(context, ref, mode),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Text(value,
          style: TextStyle(color: Theme.of(context).colorScheme.outline)),
    );
  }

  Future<void> _pickTheme(
      BuildContext context, WidgetRef ref, ThemeMode current) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child:
                  Text('Appearance', style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final m in ThemeMode.values)
              ListTile(
                leading: Icon(m == current
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off),
                title: Text(themeModeLabel(m)),
                onTap: () {
                  ref.read(themeModeProvider.notifier).set(m);
                  Navigator.of(ctx).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

