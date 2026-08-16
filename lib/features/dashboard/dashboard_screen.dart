import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/hex.dart';
import '../../core/theme.dart';
import '../../data/category_repository.dart';
import '../../data/expense_repository.dart';
import '../../data/group_repository.dart';
import '../../data/profile_repository.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/expense_category.dart';
import '../../domain/models/group.dart';
import '../entry/add_expense_sheet.dart';
import '../entry/expense_actions.dart';
import '../groups/group_flow_card.dart';
import '../search/search_screen.dart';
import '../txns/transactions_screen.dart';
import 'daily_tip.dart';
import 'dashboard_charts.dart';

/// Period the dashboard Cash Flow card summarises.
enum DashPeriod { thisWeek, thisMonth, lastMonth, thisYear, allTime }

extension DashPeriodX on DashPeriod {
  String get label => switch (this) {
        DashPeriod.thisWeek => 'This week',
        DashPeriod.thisMonth => 'This month',
        DashPeriod.lastMonth => 'Last month',
        DashPeriod.thisYear => 'This year',
        DashPeriod.allTime => 'All time',
      };

  /// Half-open [start, end) range, or null for all time.
  DateTimeRange? range(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    switch (this) {
      case DashPeriod.thisWeek:
        final start = today.subtract(Duration(days: today.weekday - 1));
        return DateTimeRange(
            start: start, end: start.add(const Duration(days: 7)));
      case DashPeriod.thisMonth:
        return DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: DateTime(now.year, now.month + 1, 1));
      case DashPeriod.lastMonth:
        return DateTimeRange(
            start: DateTime(now.year, now.month - 1, 1),
            end: DateTime(now.year, now.month, 1));
      case DashPeriod.thisYear:
        return DateTimeRange(
            start: DateTime(now.year, 1, 1),
            end: DateTime(now.year + 1, 1, 1));
      case DashPeriod.allTime:
        return null;
    }
  }
}

class _DashPeriodNotifier extends Notifier<DashPeriod> {
  @override
  DashPeriod build() => DashPeriod.thisMonth;
  void set(DashPeriod p) => state = p;
}

final dashPeriodProvider =
    NotifierProvider<_DashPeriodNotifier, DashPeriod>(_DashPeriodNotifier.new);

Future<void> _showPeriodPicker(BuildContext context, WidgetRef ref) {
  final current = ref.read(dashPeriodProvider);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in DashPeriod.values)
            ListTile(
              leading: Icon(p == current
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off),
              title: Text(p.label),
              onTap: () {
                ref.read(dashPeriodProvider.notifier).set(p);
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    ),
  );
}

String _greeting(DateTime now) {
  final h = now.hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

String _displayName() {
  final email = Supabase.instance.client.auth.currentUser?.email;
  final prefix = (email ?? '').split('@').first;
  if (prefix.isEmpty) return 'there';
  return prefix[0].toUpperCase() + prefix.substring(1);
}

/// Round glass icon button used in the Home header (search).
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderIconButton(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(12),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        icon: Icon(icon, size: 22),
      ),
    );
  }
}

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(categoriesProvider);
    ref.invalidate(expensesProvider);
    await ref.read(expensesProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider);
    final categories =
        ref.watch(categoriesProvider).asData?.value ?? const <ExpenseCategory>[];
    final catMap = {for (final c in categories) c.id: c};

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: expensesAsync.when(
          loading: () => ListView(children: const [
            SizedBox(height: 320, child: Center(child: CircularProgressIndicator())),
          ]),
          error: (e, _) => ListView(children: const [
            SizedBox(height: 200),
            Icon(Icons.cloud_off, size: 44),
            SizedBox(height: 12),
            Center(child: Text('Could not load. Pull to retry.')),
          ]),
          data: (expenses) => _Content(expenses: expenses, catMap: catMap),
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  final List<Expense> expenses;
  final Map<String, ExpenseCategory> catMap;
  const _Content({required this.expenses, required this.catMap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final period = ref.watch(dashPeriodProvider);
    final r = period.range(now);
    bool inPeriod(Expense e) =>
        r == null ||
        (!e.spentAt.isBefore(r.start) && e.spentAt.isBefore(r.end));

    final periodTx = expenses.where(inPeriod).toList();
    final periodExpenses = periodTx.where((e) => e.isExpense).toList();
    final spending = periodExpenses.fold<double>(0, (s, e) => s + e.amount);
    final income =
        periodTx.where((e) => e.isIncome).fold<double>(0, (s, e) => s + e.amount);
    final expenseTx = expenses.where((e) => e.isExpense).toList();
    final recent = expenses.length > 12 ? expenses.sublist(0, 12) : expenses;

    final profileName = ref.watch(profileProvider).asData?.value?.displayName;
    final name = (profileName != null && profileName.trim().isNotEmpty)
        ? profileName.trim()
        : _displayName();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_greeting(now),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline)),
                  Text(name, style: theme.textTheme.headlineSmall),
                ],
              ),
            ),
            _HeaderIconButton(
              icon: Icons.search_rounded,
              tooltip: 'Search',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SearchScreen())),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _CashFlowCarousel(
          personal: _CashFlowCard(
            spending: spending,
            income: income,
            periodLabel: period.label,
            onTapPeriod: () => _showPeriodPicker(context, ref),
          ),
        )
            .animate()
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
        const SizedBox(height: 14),
        const DailyTipCard()
            .animate()
            .fadeIn(delay: 80.ms, duration: 350.ms)
            .slideY(begin: 0.1, end: 0),
        const SizedBox(height: 14),
        if (periodExpenses.isNotEmpty) ...[
          GlassCard(
                  child: CategoryDonut(
                      monthExpenses: periodExpenses, catMap: catMap))
              .animate()
              .fadeIn(delay: 100.ms, duration: 350.ms)
              .slideY(begin: 0.1, end: 0),
          const SizedBox(height: 14),
        ],
        if (expenseTx.isNotEmpty)
          GlassCard(child: MonthlyTrend(expenses: expenseTx))
              .animate()
              .fadeIn(delay: 200.ms, duration: 350.ms)
              .slideY(begin: 0.1, end: 0),
        const SizedBox(height: 22),
        Row(
          children: [
            Text('Recent',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            if (expenses.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const TransactionsScreen())),
                child: const Text('See all'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (expenses.isEmpty)
          const _EmptyTx()
        else
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                for (int i = 0; i < recent.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: 1,
                        color: (theme.brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black)
                            .withAlpha(18)),
                  _TxRow(expense: recent[i], cat: catMap[recent[i].categoryId]),
                ],
              ],
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 350.ms),
      ],
    );
  }
}

/// Swipeable hero: page 0 = personal cash flow, then one card per shared group.
class _CashFlowCarousel extends ConsumerStatefulWidget {
  final Widget personal;
  const _CashFlowCarousel({required this.personal});

  @override
  ConsumerState<_CashFlowCarousel> createState() => _CashFlowCarouselState();
}

class _CashFlowCarouselState extends ConsumerState<_CashFlowCarousel> {
  final _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups =
        ref.watch(groupsProvider).asData?.value ?? const <Group>[];
    final pages = <Widget>[
      widget.personal,
      for (final g in groups) GroupFlowCard(group: g),
    ];
    return Column(
      children: [
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _pc,
            itemCount: pages.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => pages[i],
          ),
        ),
        if (pages.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withAlpha(90),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CashFlowCard extends StatelessWidget {
  final double spending;
  final double income;
  final String periodLabel;
  final VoidCallback onTapPeriod;
  const _CashFlowCard({
    required this.spending,
    required this.income,
    required this.periodLabel,
    required this.onTapPeriod,
  });

  @override
  Widget build(BuildContext context) {
    final net = income - spending;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kInkLight, kInk],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: kInk.withAlpha(120),
              blurRadius: 24,
              offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Cash Flow',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Material(
                color: Colors.white.withAlpha(38),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: onTapPeriod,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 5, 8, 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(periodLabel,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                        const Icon(Icons.expand_more_rounded,
                            color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                  child: _flow(
                      'Spending', spending, const Color(0xFFFFB1B1), false)),
              Expanded(
                  child:
                      _flow('Income', income, const Color(0xFFA7F3C0), true)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Text('Net Balance',
                    style: TextStyle(color: Colors.white70)),
                const Spacer(),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(formatMoney(net),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _flow(String label, double amount, Color dot, bool alignEnd) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label.toUpperCase(),
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3)),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(formatMoney(amount),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _TxRow extends StatelessWidget {
  final Expense expense;
  final ExpenseCategory? cat;
  const _TxRow({required this.expense, required this.cat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = hexColor(cat?.color ?? '#2a78d6');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showEditExpenseSheet(context, expense),
      onLongPress: () => showExpenseActions(context, expense),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: color.withAlpha(45),
                borderRadius: BorderRadius.circular(12)),
            child: Center(
                child: Text(cat?.icon ?? '•',
                    style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.note.isEmpty ? (cat?.name ?? 'Expense') : expense.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text('${cat?.name ?? 'Uncategorized'} · ${formatDay(expense.spentAt)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          ),
          Text(
              '${expense.isIncome ? '+' : ''}${formatMoney(expense.amount)}',
              style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: expense.isIncome ? const Color(0xFF1FB56B) : null)),
        ],
      ),
      ),
    );
  }
}

class _EmptyTx extends StatelessWidget {
  const _EmptyTx();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(Icons.mic_none_rounded,
                size: 44, color: theme.colorScheme.outline),
            const SizedBox(height: 10),
            Text('No expenses yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Tap the + and speak or type',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}
