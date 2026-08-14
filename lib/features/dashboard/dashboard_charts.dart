import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/hex.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/expense_category.dart';

/// Donut of the current month's spending by category, with a legend.
/// Returns bare content — wrap it in a GlassCard.
class CategoryDonut extends StatelessWidget {
  final List<Expense> monthExpenses;
  final Map<String, ExpenseCategory> catMap;
  const CategoryDonut(
      {super.key, required this.monthExpenses, required this.catMap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final totals = <String, double>{};
    for (final e in monthExpenses) {
      final id = e.categoryId ?? 'other';
      totals[id] = (totals[id] ?? 0) + e.amount;
    }
    final total = totals.values.fold<double>(0, (s, v) => s + v);
    if (total <= 0) return const SizedBox.shrink();

    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    Color colorFor(String id) => hexColor(catMap[id]?.color ?? '#e34948');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('By category', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 118,
              height: 118,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 33,
                      startDegreeOffset: -90,
                      sections: [
                        for (final e in entries)
                          PieChartSectionData(
                            value: e.value,
                            color: colorFor(e.key),
                            title: '',
                            radius: 26,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(formatMoney(total),
                          style: theme.textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text('total',
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
                  for (final e in entries.take(6))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: colorFor(e.key),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(catMap[e.key]?.name ?? 'Other',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall),
                          ),
                          Text('${(e.value / total * 100).round()}%',
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
}

/// Bar chart of total spend for each of the last 6 months. Bare content.
class MonthlyTrend extends StatelessWidget {
  final List<Expense> expenses;
  const MonthlyTrend({super.key, required this.expenses});

  static const _abbr = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    final months = [
      for (int i = 5; i >= 0; i--) DateTime(now.year, now.month - i, 1)
    ];
    final totals = [
      for (final m in months)
        expenses
            .where(
                (e) => e.spentAt.year == m.year && e.spentAt.month == m.month)
            .fold<double>(0, (s, e) => s + e.amount)
    ];
    final maxY = totals.fold<double>(0, (m, v) => v > m ? v : m);
    if (maxY <= 0) return const SizedBox.shrink();

    final labels = [for (final m in months) _abbr[m.month]];
    final primary = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Last 6 months', style: theme.textTheme.titleMedium),
        const SizedBox(height: 18),
        SizedBox(
          height: 140,
          child: BarChart(
            BarChartData(
              maxY: maxY * 1.2,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(enabled: false),
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
                      if (i < 0 || i >= labels.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child:
                            Text(labels[i], style: theme.textTheme.bodySmall),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (int i = 0; i < totals.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: totals[i],
                        width: 18,
                        color: i == totals.length - 1
                            ? primary
                            : primary.withAlpha(120),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(5)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
