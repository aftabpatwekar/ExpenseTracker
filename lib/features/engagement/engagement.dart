import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_prefs.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../data/expense_repository.dart';
import '../../domain/models/expense.dart';

/// Milestone counts that trigger a celebration.
const List<int> kMilestones = [1, 10, 20, 50, 100, 200, 500, 1000];
const int _perLevel = 10; // expenses per level

class EngagementStats {
  final int count;
  final int streak; // consecutive days with a logged expense
  final int level; // 1-based
  final int intoLevel; // expenses into the current level (0.._perLevel-1)
  final int? nextMilestone;

  const EngagementStats({
    required this.count,
    required this.streak,
    required this.level,
    required this.intoLevel,
    required this.nextMilestone,
  });

  double get levelProgress => intoLevel / _perLevel;
  int get toNextLevel => _perLevel - intoLevel;
}

EngagementStats computeEngagement(List<Expense> expenses) {
  final count = expenses.length;
  return EngagementStats(
    count: count,
    streak: _streak(expenses),
    level: count ~/ _perLevel + 1,
    intoLevel: count % _perLevel,
    nextMilestone: kMilestones.cast<int?>().firstWhere(
          (m) => (m ?? 0) > count,
          orElse: () => null,
        ),
  );
}

int _streak(List<Expense> e) {
  if (e.isEmpty) return 0;
  final days = <DateTime>{
    for (final x in e)
      DateTime(x.spentAt.year, x.spentAt.month, x.spentAt.day)
  };
  final now = DateTime.now();
  var cursor = DateTime(now.year, now.month, now.day);
  if (!days.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
    if (!days.contains(cursor)) return 0; // no expense today or yesterday
  }
  var s = 0;
  while (days.contains(cursor)) {
    s++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return s;
}

// ---- one-time milestone celebration ----
class _CelebrationNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int? m) => state = m;
}

final celebrationProvider =
    NotifierProvider<_CelebrationNotifier, int?>(_CelebrationNotifier.new);

/// Call right after adding an expense with the new total count. Fires a
/// celebration once per milestone (persisted so it never repeats).
Future<void> maybeCelebrate(WidgetRef ref, int newCount) async {
  if (!kMilestones.contains(newCount)) return;
  final prefs = ref.read(sharedPrefsProvider);
  final done = prefs.getStringList('celebrated_milestones') ?? const [];
  if (done.contains('$newCount')) return;
  await prefs.setStringList('celebrated_milestones', [...done, '$newCount']);
  ref.read(celebrationProvider.notifier).set(newCount);
}

String milestoneTitle(int m) => switch (m) {
      1 => 'First expense! 🎉',
      10 => '10 logged! 🔥',
      20 => '20 down! 💪',
      50 => 'Half a century! 🌟',
      100 => 'Century! 🏆',
      _ => '$m logged! 🚀',
    };

String milestoneBody(int m) => switch (m) {
      1 => "You've started taking charge of your money. Keep going!",
      10 => 'The habit is forming — you\'re on a roll.',
      20 => "You're really seeing where your money goes now.",
      50 => "You're a Molbhav regular. Impressive consistency!",
      100 => 'One hundred expenses tracked. Your future self says thanks.',
      _ => 'Incredible consistency — you\'re a tracking machine.',
    };

Future<void> showCelebration(BuildContext context, int milestone) {
  final theme = Theme.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: theme.colorScheme.surfaceContainer,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  gradient: kAccentGradient, shape: BoxShape.circle),
              child: Center(
                  child: Text(milestoneTitle(milestone).characters.last,
                      style: const TextStyle(fontSize: 34))),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(milestoneTitle(milestone),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpace.sm),
            Text(milestoneBody(milestone),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: AppSpace.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Keep it up'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Home card: level ring, streak, and progress to the next level.
class ProgressCard extends ConsumerWidget {
  const ProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final expenses =
        ref.watch(expensesProvider).asData?.value ?? const <Expense>[];
    final s = computeEngagement(expenses);

    if (s.count == 0) {
      return GlassCard(
        child: Row(
          children: [
            const Text('🌱', style: TextStyle(fontSize: 28)),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Start your streak',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text('Log your first expense to begin.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      child: Row(
        children: [
          SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 54,
                  height: 54,
                  child: CircularProgressIndicator(
                    value: s.levelProgress,
                    strokeWidth: 5,
                    backgroundColor: theme.colorScheme.surfaceContainerHigh,
                    valueColor:
                        AlwaysStoppedAnimation(theme.colorScheme.primary),
                  ),
                ),
                Text('L${s.level}',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Level ${s.level}',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    if (s.streak > 0)
                      Text('🔥 ${s.streak}-day streak',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: kMarigold, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  s.nextMilestone != null
                      ? '${s.count} logged · ${s.nextMilestone! - s.count} to your ${s.nextMilestone} goal'
                      : '${s.count} logged · ${s.toNextLevel} to Level ${s.level + 1}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
