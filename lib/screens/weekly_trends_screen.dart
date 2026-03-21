import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/expense.dart';

class WeeklyTrendsScreen extends StatelessWidget {
  const WeeklyTrendsScreen({
    super.key,
    required this.expenses,
  });

  final List<Expense> expenses;

  Map<int, double> _weeklyTotals(DateTime weekStart) {
    final totals = {for (var i = 1; i <= 7; i++) i: 0.0};

    for (final expense in expenses) {
      final date = expense.date;
      final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
      final end = start.add(const Duration(days: 7));
      if (date.isBefore(start) || !date.isBefore(end)) {
        continue;
      }

      totals[date.weekday] = totals[date.weekday]! + expense.amount;
    }

    return totals;
  }

  String _weekdayLabel(int weekday) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    final totals = _weeklyTotals(weekStart);
    final weeklyTotal =
        totals.values.fold<double>(0, (sum, item) => sum + item);

    final highestEntry = totals.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

    final maxY = totals.values.fold<double>(0, (a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Spending Trends'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Spending Trend',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 250,
                      child: LineChart(
                        LineChartData(
                          minX: 1,
                          maxX: 7,
                          minY: 0,
                          maxY: (maxY == 0 ? 100 : maxY * 1.25),
                          gridData: FlGridData(
                            drawHorizontalLine: true,
                            drawVerticalLine: false,
                            horizontalInterval: (maxY == 0 ? 20 : (maxY / 4)),
                          ),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, _) {
                                  final day = value.toInt();
                                  if (day < 1 || day > 7) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(_weekdayLabel(day)),
                                  );
                                },
                              ),
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: totals.entries
                                  .map((entry) =>
                                      FlSpot(entry.key.toDouble(), entry.value))
                                  .toList(),
                              isCurved: true,
                              barWidth: 3,
                              color: Theme.of(context).colorScheme.primary,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Total weekly spending: ₹${weeklyTotal.toStringAsFixed(0)}'),
                    const SizedBox(height: 6),
                    Text(
                      'Highest spending day: ${_weekdayLabel(highestEntry.key)} '
                      '(₹${highestEntry.value.toStringAsFixed(0)})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
