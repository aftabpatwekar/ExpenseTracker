import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/hex.dart';
import '../../data/category_repository.dart';
import '../../data/expense_repository.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/expense_category.dart';

enum _Range { week, month, quarter, year }

extension on _Range {
  String get label => switch (this) {
        _Range.week => 'Week',
        _Range.month => 'Month',
        _Range.quarter => '3 Months',
        _Range.year => 'Year',
      };
}

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

List<_Bucket> _buildBuckets(_Range range, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final out = <_Bucket>[];
  switch (range) {
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
    case _Range.quarter:
      for (var i = 11; i >= 0; i--) {
        final end = today.subtract(Duration(days: i * 7)).add(const Duration(days: 1));
        final start = end.subtract(const Duration(days: 7));
        out.add(_Bucket('${start.day}/${start.month}', start, end));
      }
    case _Range.year:
      for (var i = 11; i >= 0; i--) {
        final m = DateTime(now.year, now.month - i, 1);
        out.add(_Bucket(_mo[m.month], m, DateTime(m.year, m.month + 1, 1)));
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
  int _touchedDonut = -1;

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
    final buckets = _buildBuckets(_range, now);
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
    final perDay = days > 0 ? total / days : 0.0;
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Analysis',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final r in _Range.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(r.label),
                      selected: _range == r,
                      onSelected: (_) => setState(() {
                        _range = r;
                        _touchedDonut = -1;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(child: _trendChart(theme, buckets, total)),
          const SizedBox(height: 14),
          GlassCard(child: _statsRow(theme, total, perDay, perTxn, inRange.length)),
          const SizedBox(height: 14),
          if (catEntries.isNotEmpty)
            GlassCard(child: _donutCard(theme, catEntries, catMap, total)),
          const SizedBox(height: 14),
          GlassCard(child: _breakdown(theme, catEntries, catMap, total)),
        ],
      ),
    );
  }

  // ---- spending trend (interactive bars) ----
  Widget _trendChart(ThemeData theme, List<_Bucket> buckets, double total) {
    final maxY = buckets.fold<double>(0, (m, b) => b.total > m ? b.total : m);
    final labelEvery = buckets.length > 12 ? 5 : 1;
    final primary = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Spending · ${_range.label}', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(formatMoney(total),
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        SizedBox(
          height: 150,
          child: maxY <= 0
              ? Center(
                  child: Text('No spending in this range',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)))
              : BarChart(
                  BarChartData(
                    maxY: maxY * 1.2,
                    alignment: BarChartAlignment.spaceAround,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                          formatMoney(rod.toY),
                          const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700),
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
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 ||
                                i >= buckets.length ||
                                i % labelEvery != 0) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(buckets[i].label,
                                  style: const TextStyle(fontSize: 10)),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < buckets.length; i++)
                        BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: buckets[i].total,
                            width: buckets.length > 14 ? 6 : 14,
                            color: primary,
                            borderRadius:
                                const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ]),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _statsRow(ThemeData theme, double total, double perDay, double perTxn,
      int count) {
    Widget stat(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontWeight: FontWeight.w600,
                      fontSize: 10)),
              const SizedBox(height: 2),
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

  // ---- interactive donut ----
  Widget _donutCard(ThemeData theme, List<MapEntry<String, double>> entries,
      Map<String, ExpenseCategory> catMap, double total) {
    Color colorFor(String id) => hexColor(catMap[id]?.color ?? '#e34948');
    final touched =
        (_touchedDonut >= 0 && _touchedDonut < entries.length)
            ? entries[_touchedDonut]
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('By category', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 128,
              height: 128,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 36,
                      startDegreeOffset: -90,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                response?.touchedSection == null) {
                              _touchedDonut = -1;
                            } else {
                              _touchedDonut = response!
                                  .touchedSection!.touchedSectionIndex;
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
                            radius: i == _touchedDonut ? 30 : 24,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          touched == null
                              ? formatMoney(total)
                              : formatMoney(touched.value),
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text(
                          touched == null
                              ? 'total'
                              : (catMap[touched.key]?.name ?? 'Other'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < entries.length && i < 6; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  color: colorFor(entries[i].key),
                                  borderRadius: BorderRadius.circular(3))),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(catMap[entries[i].key]?.name ?? 'Other',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall),
                          ),
                          Text('${(entries[i].value / total * 100).round()}%',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.outline)),
                        ],
                      ),
                    ),
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
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('No spending in this range.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
          )
        else
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(catMap[e.key]?.icon ?? '•',
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
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
                      backgroundColor: hexColor(catMap[e.key]?.color ?? '#e34948')
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
