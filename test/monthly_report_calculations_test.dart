import 'package:budget_tracker/models/expense.dart';
import 'package:budget_tracker/screens/monthly_report_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Expense makeExpense({
    required int amount,
    required DateTime date,
    String title = 'Item',
    String category = 'Food',
  }) {
    return Expense(
      title: title,
      amount: amount,
      category: category,
      date: date,
      userId: 'demo-user',
      synced: false,
    );
  }

  test('totalSpent sums expense amounts correctly', () {
    final now = DateTime.now();
    final report = MonthlyReportScreen(
      expenses: [
        makeExpense(amount: 120, date: now),
        makeExpense(amount: 80, date: now),
        makeExpense(amount: 300, date: now),
      ],
      monthlyBudget: 5000,
      rent: 1000,
    );

    expect(report.totalSpent, 500);
  });

  test('dailyLimit correctly computes using current month days', () {
    final now = DateTime.now();
    final report = MonthlyReportScreen(
      expenses: [
        makeExpense(amount: 1200, date: now),
        makeExpense(amount: 600, date: now),
      ],
      monthlyBudget: 5000,
      rent: 1000,
    );

    final availableBudget = report.availableBudget;
    final remaining = availableBudget - report.totalSpent;
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final daysRemaining = lastDayOfMonth.day - now.day + 1;
    final expectedDailyLimit =
        daysRemaining <= 0 ? remaining : (remaining / daysRemaining).floor();

    expect(report.dailyLimit, expectedDailyLimit);
  });

  test('remaining equals availableBudget minus totalSpent', () {
    final now = DateTime.now();
    final report = MonthlyReportScreen(
      expenses: [
        makeExpense(amount: 900, date: now),
        makeExpense(amount: 100, date: now),
      ],
      monthlyBudget: 6000,
      rent: 2000,
    );

    expect(report.remaining, report.availableBudget - report.totalSpent);
    expect(report.remaining, 3000);
  });
}
