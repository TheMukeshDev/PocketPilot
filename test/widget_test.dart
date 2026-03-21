import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:budget_tracker/main.dart';
import 'package:budget_tracker/models/expense.dart';
import 'package:budget_tracker/screens/home_screen.dart';
import 'package:budget_tracker/services/database_service.dart';
import 'package:sqflite/sqflite.dart';

class FakeExpenseStore implements ExpenseStore {
  final List<Expense> _items = [];
  int _nextId = 1;

  @override
  Future<void> deleteExpense(int id) async {
    _items.removeWhere((expense) => expense.id == id);
  }

  @override
  Future<List<Expense>> getExpenses(String? userId) async {
    return List<Expense>.from(_items);
  }

  @override
  Future<Database> initDatabase() {
    throw UnimplementedError();
  }

  @override
  Future<void> markSynced(int id) async {}

  @override
  Future<Expense> insertExpense(Expense expense) async {
    final savedExpense = expense.copyWith(id: _nextId++);
    _items.insert(0, savedExpense);
    return savedExpense;
  }
}

void main() {
  testWidgets('renders budget tracker home screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MyApp(
        home: HomeScreen(expenseStore: FakeExpenseStore()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('PocketPilot'), findsOneWidget);
    expect(find.text('Add Expense'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Monthly Budget'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Monthly Budget'), findsOneWidget);
    expect(find.text('Fixed Rent'), findsOneWidget);
    expect(find.text('Total Spent'), findsOneWidget);
    expect(find.text('Today Spend'), findsOneWidget);
    expect(find.text('Left to Spend'), findsOneWidget);
    expect(find.text('Daily Safe Limit'), findsOneWidget);
  });
}
