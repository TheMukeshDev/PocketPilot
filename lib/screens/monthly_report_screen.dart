import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../services/prediction_service.dart';
import '../widgets/budget_card.dart';
import '../widgets/spending_chart.dart';

class MonthlyReportScreen extends StatelessWidget {
  const MonthlyReportScreen({
    super.key,
    required this.expenses,
    required this.monthlyBudget,
    required this.rent,
  });

  final List<Expense> expenses;
  final int monthlyBudget;
  final int rent;

  List<Expense> get currentMonthExpenses {
    final now = DateTime.now();
    return expenses
        .where((expense) => expense.date.year == now.year && expense.date.month == now.month)
        .toList();
  }

  int get totalSpent {
    return currentMonthExpenses.fold(0, (sum, item) => sum + item.amount);
  }

  int get availableBudget {
    return monthlyBudget - rent;
  }

  int get remaining {
    return availableBudget - totalSpent;
  }

  int get dailyLimit {
    final now = DateTime.now();
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final daysRemaining = lastDayOfMonth.day - now.day + 1;
    if (daysRemaining <= 0) {
      return remaining;
    }

    return (remaining / daysRemaining).floor();
  }

  Map<String, double> get categoryTotals {
    final totals = {
      for (final category in kExpenseCategories) category: 0.0,
    };
    for (final expense in currentMonthExpenses) {
      final key = totals.containsKey(expense.category) ? expense.category : 'Other';
      totals[key] = totals[key]! + expense.amount;
    }
    return totals;
  }

  List<Expense> get topExpenses {
    final sorted = List<Expense>.from(currentMonthExpenses)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return sorted.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final prediction = PredictionService.analyze(
      totalSpent: totalSpent,
      availableBudget: availableBudget,
    );

    final filteredCategoryEntries = categoryTotals.entries
        .where((entry) => entry.value > 0)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Report'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 380;
            final barWidth = compact ? 16.0 : 22.0;
            final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                );

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                BudgetCard(
                  title: 'Total Budget',
                  value: '₹$availableBudget',
                ),
                BudgetCard(
                  title: 'Spent (This Month)',
                  value: '₹$totalSpent',
                ),
                BudgetCard(
                  title: 'Remaining',
                  value: '₹$remaining',
                  valueColor: remaining < 0 ? colorScheme.error : colorScheme.primary,
                ),
                const SizedBox(height: 8),
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
                        Text('Category Bar Chart', style: titleStyle),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: compact ? 220 : 260,
                          child: filteredCategoryEntries.isEmpty
                              ? const Center(child: Text('No current-month data to display.'))
                              : BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: (filteredCategoryEntries
                                                .map((entry) => entry.value)
                                                .reduce((a, b) => a > b ? a : b) *
                                            1.2)
                                        .clamp(100, double.infinity),
                                    gridData: const FlGridData(show: false),
                                    borderData: FlBorderData(show: false),
                                    titlesData: FlTitlesData(
                                      topTitles: const AxisTitles(
                                        sideTitles: SideTitles(showTitles: false),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles: SideTitles(showTitles: false),
                                      ),
                                      leftTitles: const AxisTitles(
                                        sideTitles: SideTitles(showTitles: false),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: compact ? 44 : 32,
                                          getTitlesWidget: (value, meta) {
                                            final index = value.toInt();
                                            if (index < 0 ||
                                                index >= filteredCategoryEntries.length) {
                                              return const SizedBox.shrink();
                                            }
                                            final label = filteredCategoryEntries[index].key;
                                            final short = label.length > 8
                                                ? '${label.substring(0, 8)}…'
                                                : label;
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 8),
                                              child: Text(
                                                short,
                                                style: Theme.of(context).textTheme.bodySmall,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    barGroups: filteredCategoryEntries.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final category = entry.value.key;
                                      final amount = entry.value.value;
                                      return BarChartGroupData(
                                        x: index,
                                        barRods: [
                                          BarChartRodData(
                                            toY: amount,
                                            width: barWidth,
                                            color: categoryColor(context, category),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ],
                                      );
                                    }).toList(),
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
                        Text('Top 3 Expenses (This Month)', style: titleStyle),
                        const SizedBox(height: 10),
                        if (topExpenses.isEmpty)
                          const Text('No expenses yet for this month.')
                        else
                          ...topExpenses.map(
                            (expense) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(expense.title),
                              subtitle: Text(expense.category),
                              trailing: Text(
                                '₹${expense.amount}',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Monthly Summary', style: titleStyle),
                        const SizedBox(height: 10),
                        Text('Daily limit: ₹$dailyLimit'),
                        Text('Current-month entries: ${currentMonthExpenses.length}'),
                        Text('Budget used: '
                            '${availableBudget == 0 ? 0 : ((totalSpent / availableBudget) * 100).toStringAsFixed(1)}%'),
                        Text(prediction.message),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}