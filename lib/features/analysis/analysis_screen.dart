import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/hex.dart';
import '../../core/theme.dart';
import '../../data/category_repository.dart';
import '../../data/expense_repository.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/expense_category.dart';
import '../reports/reports_screen.dart';

enum _Range { today, week, month, year, custom }

extension on _Range {
  String get label => switch (this) {
        _Range.today => 'Today',
        _Range.week => 'Week',
        _Range.month => 'Month',
        _Range.year => 'Year',
        _Range.custom => 'Custom',
      };
}

enum _ChartType { bar, line }

class _Bucket {
  final String label;
  final DateTime start;
  final DateTime end;
  double total = 0;
  _Bucket(this.label, this.start, this.end);
}

const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _mo = [
  '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

List<_Bucket> _buildBuckets(_Range range, DateTime now, DateTimeRange? custom) {
  final today = DateTime(now.year, now.month, now.day);
  final out = <_Bucket>[];
  switch (range) {
    case _Range.today:
      for (var h = 0; h < 24; h += 6) {
        final start = today.add(Duration(hours: h));
        final end = start.add(const Duration(hours: 6));
        final ampm = h == 0
            ? '12a'
            : h < 12
                ? '${h}a'
                : h == 12
                    ? '12p'
                    : '${h - 12}p';
        out.add(_Bucket(ampm, start, end));
      }
    case _Range.week:
      for (var i = 6; i >= 0; i--) {
        final d = today.subtract(Duration(days: i));
        out.add(_Bucket(_wd[d.weekday - 1], d, d.add(const Duration(days: 1))));
      }
    case _Range.month:
      for (var i = 29; i >= 0; i--) {
        final d = today.subtract(Duration(days: i));
        out.add(_Bucket('${d.day}', d, d.add(const Duration(days: 1))));
      }
    case _Range.year:
      for (var i = 11; i >= 0; i--) {
        final m = DateTime(now.year, now.month - i, 1);
        out.add(_Bucket(_mo[m.month], m, DateTime(m.year, m.month + 1, 1)));
      }
    case _Range.custom:
      final r = custom ??
          DateTimeRange(
              start: today.subtract(const Duration(days: 29)),
              end: today);
      final startDay = DateTime(r.start.year, r.start.month, r.start.day);
      final endDay = DateTime(r.end.year, r.end.month, r.end.day)
          .add(const Duration(days: 1));
      final span = endDay.difference(startDay).inDays;
      if (span <= 31) {
        for (var d = startDay;
            d.isBefore(endDay);
            d = d.add(const Duration(days: 1))) {
          out.add(_Bucket('${d.day}/${d.month}', d,
              d.add(const Duration(days: 1))));
        }
      } else if (span <= 182) {
        for (var d = startDay;
            d.isBefore(endDay);
            d = d.add(const Duration(days: 7))) {
          final e = d.add(const Duration(days: 7));
          out.add(_Bucket('${d.day}/${d.month}', d, e));
        }
      } else {
        var m = DateTime(r.start.year, r.start.month, 1);
        while (m.isBefore(endDay)) {
          final e = DateTime(m.year, m.month + 1, 1);
          out.add(_Bucket(_mo[m.month], m, e));
          m = e;
        }
      }
  }
  return out;
}

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  _Range _range = _Range.month;
  _ChartType _chartType = _ChartType.bar;
  DateTimeRange? _custom;
  int _touchedDonut = -1;

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _custom ??
          DateTimeRange(
              start: now.subtract(const Duration(days: 29)), end: now),
    );
    if (picked != null && mounted) {
      setState(() {
        _custom = picked;
        _range = _Range.custom;
        _touchedDonut = -1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenses =
        ref.watch(expensesProvider).asData?.value ?? const <Expense>[];
    final cats =
        ref.watch(categoriesProvider).asData?.value ?? const <ExpenseCategory>[];
    final catMap = {for (final c in cats) c.id: c};
    final now = DateTime.now();

    final spending = expenses.where((e) => e.isExpense).toList();
    final buckets = _buildBuckets(_range, now, _custom);
    final rangeStart = buckets.first.start;
    final rangeEnd = buckets.last.end;
    final inRange = spending
        .where((e) =>
            !e.spentAt.isBefore(rangeStart) && e.spentAt.isBefore(rangeEnd))
        .toList();

    for (final e in inRange) {
      for (final b in buckets) {
        if (!e.spentAt.isBefore(b.start) && e.spentAt.isBefore(b.end)) {
          b.total += e.amount;
          break;
        }
      }
    }

    final total = inRange.fold<double>(0, (s, e) => s + e.amount);
    final days = rangeEnd.difference(rangeStart).inDays;
    final perDay = days > 0 ? total / days : total;
    final perTxn = inRange.isEmpty ? 0.0 : total / inRange.length;

    final catTotals = <String, double>{};
    for (final e in inRange) {
      final id = e.categoryId ?? 'other';
      catTotals[id] = (catTotals[id] ?? 0) + e.amount;
    }
    final catEntries = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.sm, AppSpace.lg, 120),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text('Analysis',
                      style: theme.textTheme.headlineSmall),
                ),
                _RoundIconButton(
                  icon: Icons.description_outlined,
                  tooltip: 'Reports',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ReportsScreen())),
                ),
              ],
            ),
          ),
          // The common glass slider.
          GlassSegmented(
            labels: [for (final r in _Range.values) r.label],
            selected: _Range.values.indexOf(_range),
            onChanged: (i) {
              final r = _Range.values[i];
              if (r == _Range.custom) {
                _pickCustom();
              } else {
                setState(() {
                  _range = r;
                  _touchedDonut = -1;
                });
              }
            },
          ),
          if (_range == _Range.custom && _custom != null) ...[
            const SizedBox(height: AppSpace.md),
            _CustomRangeBar(
              range: _custom!,
              onEdit: _pickCustom,
            ),
          ],
          const SizedBox(height: AppSpace.lg),
          GlassCard(child: _trendCard(theme, buckets, total)),
          const SizedBox(height: AppSpace.lg),
          GlassCard(
              child: _statsRow(theme, perDay, perTxn, inRange.length)),
          const SizedBox(height: AppSpace.lg),
          if (catEntries.isNotEmpty)
            GlassCard(child: _donutCard(theme, catEntries, catMap, total)),
          const SizedBox(height: AppSpace.lg),
          GlassCard(child: _breakdown(theme, catEntries, catMap, total)),
        ],
      ),
    );
  }

  // ---- spending trend (bar or line, interactive) ----
  Widget _trendCard(ThemeData theme, List<_Bucket> buckets, double total) {
    final maxY = buckets.fold<double>(0, (m, b) => b.total > m ? b.total : m);
    final labelEvery = buckets.length > 12 ? 5 : 1;
    // Fresh key per range/type so fl_chart animates in cleanly instead of
    // morphing across mismatched bucket counts (the old "flicker").
    final chartKey = ValueKey('${_range.name}-${_chartType.name}-${buckets.length}');

    Widget bottomTitle(double value, TitleMeta meta) {
      final i = value.toInt();
      if (i < 0 || i >= buckets.length || i % labelEvery != 0) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(buckets[i].label,
            style: TextStyle(
                fontSize: 10, color: theme.colorScheme.outline)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Spending · ${_range.label}',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(formatMoney(total),
                      style: theme.textTheme.headlineSmall),
                ],
              ),
            ),
            _MiniToggle(
              selected: _chartType.index,
              icons: const [Icons.bar_chart_rounded, Icons.show_chart_rounded],
              onChanged: (i) =>
                  setState(() => _chartType = _ChartType.values[i]),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.lg),
        SizedBox(
          height: 170,
          child: maxY <= 0
              ? Center(
                  child: Text('No spending in this range',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)))
              : _chartType == _ChartType.bar
                  ? BarChart(
                      key: chartKey,
                      BarChartData(
                        maxY: maxY * 1.2,
                        alignment: BarChartAlignment.spaceAround,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => kDarkSurface2,
                            getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                              formatMoney(rod.toY),
                              const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 24,
                                getTitlesWidget: bottomTitle),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < buckets.length; i++)
                            BarChartGroupData(x: i, barRods: [
                              BarChartRodData(
                                toY: buckets[i].total,
                                width: buckets.length > 14 ? 6 : 16,
                                gradient: kAccentGradient,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6)),
                              ),
                            ]),
                        ],
                      ),
                    )
                  : LineChart(
                      key: chartKey,
                      LineChartData(
                        maxY: maxY * 1.2,
                        minY: 0,
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (_) => kDarkSurface2,
                            getTooltipItems: (spots) => spots
                                .map((s) => LineTooltipItem(
                                    formatMoney(s.y),
                                    const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700)))
                                .toList(),
                          ),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 24,
                                getTitlesWidget: bottomTitle),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < buckets.length; i++)
                                FlSpot(i.toDouble(), buckets[i].total),
                            ],
                            isCurved: true,
                            preventCurveOverShooting: true,
                            gradient: kAccentGradient,
                            barWidth: 3,
                            dotData: FlDotData(
                              show: buckets.length <= 12,
                              getDotPainter: (s, _, _, _) =>
                                  FlDotCirclePainter(
                                      radius: 3,
                                      color: Colors.white,
                                      strokeWidth: 2,
                                      strokeColor: kAccent),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  kAccent.withAlpha(70),
                                  kAccent.withAlpha(0),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _statsRow(ThemeData theme, double perDay, double perTxn, int count) {
    Widget stat(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 0.4)),
              const SizedBox(height: 4),
              Text(value,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        );
    return Row(
      children: [
        stat('Avg / day', formatMoney(perDay)),
        stat('Avg / txn', formatMoney(perTxn)),
        stat('Entries', '$count'),
      ],
    );
  }

  // ---- interactive donut (big, center labels — no overlap) ----
  Widget _donutCard(ThemeData theme, List<MapEntry<String, double>> entries,
      Map<String, ExpenseCategory> catMap, double total) {
    Color colorFor(String id) => hexColor(catMap[id]?.color ?? '#e34948');
    final touched = (_touchedDonut >= 0 && _touchedDonut < entries.length)
        ? entries[_touchedDonut]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('By category', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpace.lg),
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 68,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            response?.touchedSection == null) {
                          _touchedDonut = -1;
                        } else {
                          _touchedDonut =
                              response!.touchedSection!.touchedSectionIndex;
                        }
                      });
                    },
                  ),
                  sections: [
                    for (var i = 0; i < entries.length; i++)
                      PieChartSectionData(
                        value: entries[i].value,
                        color: colorFor(entries[i].key),
                        title: '',
                        radius: i == _touchedDonut ? 40 : 32,
                      ),
                  ],
                ),
              ),
              // Center label: total, or the tapped slice — never on the slices,
              // so labels can't overlap the chart.
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      touched == null
                          ? formatMoney(total)
                          : formatMoney(touched.value),
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                      touched == null
                          ? 'Total spent'
                          : (catMap[touched.key]?.name ?? 'Other'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                  if (touched != null)
                    Text('${(touched.value / total * 100).round()}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: colorFor(touched.key),
                            fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Wrap(
          spacing: AppSpace.md,
          runSpacing: AppSpace.sm,
          children: [
            for (var i = 0; i < entries.length; i++)
              GestureDetector(
                onTap: () => setState(() =>
                    _touchedDonut = _touchedDonut == i ? -1 : i),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: colorFor(entries[i].key),
                            borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 6),
                    Text(catMap[entries[i].key]?.name ?? 'Other',
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: i == _touchedDonut
                                ? FontWeight.w700
                                : FontWeight.w500)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _breakdown(ThemeData theme, List<MapEntry<String, double>> entries,
      Map<String, ExpenseCategory> catMap, double total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category breakdown', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpace.md),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
            child: Text('No spending in this range.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
          )
        else
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(catMap[e.key]?.icon ?? '•',
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                          child: Text(catMap[e.key]?.name ?? 'Other',
                              style: theme.textTheme.bodyMedium)),
                      Text(formatMoney(e.value),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: total > 0 ? e.value / total : 0,
                      minHeight: 6,
                      backgroundColor:
                          hexColor(catMap[e.key]?.color ?? '#e34948')
                              .withAlpha(40),
                      valueColor: AlwaysStoppedAnimation(
                          hexColor(catMap[e.key]?.color ?? '#e34948')),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _RoundIconButton(
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
        icon: Icon(icon, size: 20),
      ),
    );
  }
}

class _MiniToggle extends StatelessWidget {
  final int selected;
  final List<IconData> icons;
  final ValueChanged<int> onChanged;
  const _MiniToggle(
      {required this.selected, required this.icons, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < icons.length; i++)
            GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: i == selected ? kAccent : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(icons[i],
                    size: 18,
                    color: i == selected
                        ? Colors.white
                        : theme.colorScheme.outline),
              ),
            ),
        ],
      ),
    );
  }
}

class _CustomRangeBar extends StatelessWidget {
  final DateTimeRange range;
  final VoidCallback onEdit;
  const _CustomRangeBar({required this.range, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg, vertical: AppSpace.md),
      onTap: onEdit,
      child: Row(
        children: [
          Icon(Icons.date_range_rounded,
              size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
                '${formatDay(range.start)} — ${formatDay(range.end)}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Text('Change',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.primary)),
        ],
      ),
    );
  }
}
