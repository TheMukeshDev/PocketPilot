import 'dart:math';

import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../services/auth_service.dart';
import '../services/expense_service.dart';
import '../widgets/main_bottom_nav.dart';
import 'payment_history_screen.dart';
import 'scan_receipt_screen.dart';
import 'scan_qr_payment_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({
    super.key,
    required this.alertMessages,
  });

  final List<String> alertMessages;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  static const List<String> _tips = <String>[
    'Set a daily limit and track before every payment.',
    'Save ₹10 first thing in the morning for consistency.',
    'Reduce one non-essential purchase today.',
    'Check top expense category and cut it by 10%.',
    'Review all UPI spends nightly for better control.',
  ];

  late String _todayTip;

  @override
  void initState() {
    super.initState();
    final random = Random(DateTime.now().day + DateTime.now().month);
    _todayTip = _tips[random.nextInt(_tips.length)];
  }

  Future<void> _openPayFlow() async {
    final paidExpense = await Navigator.of(context).push<Expense>(
      MaterialPageRoute(builder: (_) => const ScanQrPaymentScreen()),
    );

    if (paidExpense == null || !mounted) {
      return;
    }

    await ExpenseService.instance.addExpense(
      paidExpense,
      AuthService.instance.currentUser,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment added to expense history.')),
    );
  }

  Future<void> _openHistory() async {
    final expenses = await ExpenseService.instance.getExpensesForUser(
      AuthService.instance.currentUser,
    );
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaymentHistoryScreen(expenses: expenses),
      ),
    );
  }

  Future<void> _openAddReceiptFlow() async {
    final newExpense = await Navigator.of(context).push<Expense>(
      MaterialPageRoute(builder: (_) => const ScanReceiptScreen()),
    );

    if (newExpense == null || !mounted) {
      return;
    }

    await ExpenseService.instance.addExpense(
      newExpense,
      AuthService.instance.currentUser,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt expense added to history.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryAlert = widget.alertMessages.isNotEmpty
        ? widget.alertMessages.first
        : 'No critical alert right now. Great budget control!';

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      bottomNavigationBar: MainBottomNav(
        currentTab: AppBottomTab.alerts,
        alertsCount: widget.alertMessages.length,
        onHomeTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
        onAlertsTap: () {},
        onPayTap: _openPayFlow,
        onAddReceiptTap: _openAddReceiptFlow,
        onHistoryTap: _openHistory,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active_rounded),
              title: const Text('Primary Alert'),
              subtitle: Text(primaryAlert),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lightbulb_outline_rounded),
              title: const Text('Today\'s Savings Suggestion'),
              subtitle: Text(_todayTip),
            ),
          ),
        ],
      ),
    );
  }
}
