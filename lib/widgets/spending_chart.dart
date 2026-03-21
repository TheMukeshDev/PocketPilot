import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/expense.dart';

const List<String> kExpenseCategories = [
  'Food',
  'Travel',
  'Shopping',
  'Recharge',
  'Medical',
  'Utilities',
  'Entertainment',
  'Study',
  'Personal',
  'Other',
];

Color categoryColor(BuildContext context, String category) {
  final colorScheme = Theme.of(context).colorScheme;
  final palette = <Color>[
    colorScheme.primary,
    colorScheme.secondary,
    colorScheme.tertiary,
    colorScheme.error,
    colorScheme.primaryContainer,
    colorScheme.secondaryContainer,
    colorScheme.tertiaryContainer,
    colorScheme.inversePrimary,
    colorScheme.onPrimaryContainer,
    colorScheme.onSecondaryContainer,
  ];

  final index = kExpenseCategories.indexOf(category);
  if (index < 0) {
    return colorScheme.outline;
  }
  return palette[index % palette.length];
}

class SpendingChart extends StatelessWidget {
  const SpendingChart({super.key, required this.expenses});

  final List<Expense> expenses;

  Map<String, double> _categorySpending(List<Expense> monthExpenses) {
    final totals = {
      for (final category in kExpenseCategories) category: 0.0,
    };

    for (final expense in monthExpenses) {
      final key =
          totals.containsKey(expense.category) ? expense.category : 'Other';
      totals[key] = totals[key]! + expense.amount;
    }

    return totals;
  }

  List<Expense> get _currentMonthExpenses {
    final now = DateTime.now();
    return expenses
        .where(
          (expense) =>
              expense.date.year == now.year && expense.date.month == now.month,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final monthExpenses = _currentMonthExpenses;
    final totals = _categorySpending(monthExpenses);
    final totalSpent =
        totals.values.fold<double>(0, (sum, value) => sum + value);
    final activeCategories =
        kExpenseCategories.where((category) => totals[category]! > 0).toList();

    if (totalSpent == 0) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: Text('Add current-month expenses to see category insights.'),
        ),
      );
    }

    final sections = activeCategories.map((category) {
      final value = totals[category]!;
      final percent = (value / totalSpent) * 100;

      return PieChartSectionData(
        color: categoryColor(context, category),
        value: value,
        title: '${percent.toStringAsFixed(0)}%',
        radius: 62,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      );
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final chartSize = compact ? 200.0 : 230.0;
        final centerSpace = compact ? 36.0 : 46.0;

        return Column(
          children: [
            SizedBox(
              height: chartSize,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: centerSpace,
                  sections: sections,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: activeCategories.map((category) {
                final percent = (totals[category]! / totalSpent) * 100;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: categoryColor(context, category),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$category ${percent.toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}
