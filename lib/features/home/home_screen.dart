import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';

/// Temporary landing screen — a setup/health check.
/// Replaced by the auth gate + dashboard in the next phases.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = Supabase.instance.client.auth.currentSession;
    final host = Uri.tryParse(Env.supabaseUrl)?.host ?? Env.supabaseUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('Expense Tracker')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.savings_outlined,
                  size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Setup looking good', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              _CheckRow(ok: true, label: 'Flutter app running'),
              _CheckRow(
                ok: Env.isConfigured,
                label: Env.isConfigured
                    ? 'Backend connected · $host'
                    : 'Backend not configured (.env)',
              ),
              _CheckRow(
                ok: session != null,
                label: session == null
                    ? 'Not signed in — auth is next'
                    : 'Signed in',
                pendingIcon: Icons.lock_outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final bool ok;
  final String label;
  final IconData pendingIcon;
  const _CheckRow({
    required this.ok,
    required this.label,
    this.pendingIcon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.check_circle : pendingIcon,
              size: 20, color: ok ? scheme.primary : scheme.outline),
          const SizedBox(width: 10),
          Flexible(child: Text(label)),
        ],
      ),
    );
  }
}
