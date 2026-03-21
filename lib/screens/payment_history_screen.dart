import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../services/auth_service.dart';
import '../services/expense_service.dart';
import '../widgets/main_bottom_nav.dart';
import 'add_expense_screen.dart';
import 'alerts_screen.dart';
import 'scan_receipt_screen.dart';
import 'scan_qr_payment_screen.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({
    super.key,
    required this.expenses,
  });

  final List<Expense> expenses;

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  late List<Expense> _expenses;

  @override
  void initState() {
    super.initState();
    _expenses = List<Expense>.from(widget.expenses);
    _sortExpenses();
  }

  void _sortExpenses() {
    _expenses.sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> _openPayFlow() async {
    final paidExpense = await Navigator.of(context).push<Expense>(
      MaterialPageRoute(builder: (_) => const ScanQrPaymentScreen()),
    );

    if (paidExpense == null || !mounted) return;

    final saved = await ExpenseService.instance.addExpense(
      paidExpense,
      AuthService.instance.currentUser,
    );

    if (!mounted) return;

    setState(() {
      _expenses.insert(0, saved);
    });
  }

  Future<void> _openAddReceiptFlow() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.document_scanner_rounded),
                title: const Text('Scan Receipt'),
                subtitle: const Text('Use camera/gallery auto-detection'),
                onTap: () => Navigator.of(sheetContext).pop('scan'),
              ),
              ListTile(
                leading: const Icon(Icons.edit_note_rounded),
                title: const Text('Add Manually'),
                subtitle: const Text('Enter title, amount and category'),
                onTap: () => Navigator.of(sheetContext).pop('manual'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    Expense? newExpense;
    if (action == 'manual') {
      newExpense = await Navigator.of(context).push<Expense>(
        MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
      );
    } else {
      newExpense = await Navigator.of(context).push<Expense>(
        MaterialPageRoute(builder: (_) => const ScanReceiptScreen()),
      );
    }

    if (newExpense == null || !mounted) return;

    final saved = await ExpenseService.instance.addExpense(
      newExpense,
      AuthService.instance.currentUser,
    );

    if (!mounted) return;

    setState(() {
      _expenses.insert(0, saved);
    });
  }

  Future<void> _deleteExpense(Expense expense, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Delete "${expense.title}" (₹${expense.amount})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await ExpenseService.instance.deleteExpense(expense);

    setState(() {
      _expenses.removeAt(index);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expense deleted')),
    );
  }

  Future<void> _editExpense(Expense expense, int index) async {
    final updated = await Navigator.of(context).push<Expense>(
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(expenseToEdit: expense),
      ),
    );

    if (updated == null || !mounted) return;

    await ExpenseService.instance.updateExpense(updated);

    setState(() {
      _expenses[index] = updated;
      _sortExpenses();
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expense updated')),
    );
  }

  Future<void> _deleteAllExpenses() async {
    if (_expenses.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Expenses'),
        content: Text('Delete all ${_expenses.length} expenses? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    for (final expense in _expenses) {
      await ExpenseService.instance.deleteExpense(expense);
    }

    setState(() {
      _expenses.clear();
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All expenses deleted')),
    );
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour12 = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$day/$month/$year, $hour12:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final alerts = <String>[
      if (_expenses.isNotEmpty)
        'You have ${_expenses.length} transactions.',
      if (_expenses.isEmpty)
        'No expenses tracked yet.',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense History'),
        actions: [
          if (_expenses.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Delete All',
              onPressed: _deleteAllExpenses,
            ),
        ],
      ),
      bottomNavigationBar: MainBottomNav(
        currentTab: AppBottomTab.history,
        alertsCount: alerts.length,
        onHomeTap: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        onAlertsTap: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => AlertsScreen(alertMessages: alerts),
            ),
          );
        },
        onPayTap: _openPayFlow,
        onAddReceiptTap: _openAddReceiptFlow,
        onHistoryTap: () {},
      ),
      body: _expenses.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 64,
                      color: colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No expenses yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add expenses using Scan or Add button',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
              itemCount: _expenses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final expense = _expenses[index];
                return Dismissible(
                  key: ValueKey(expense.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) async {
                    await _deleteExpense(expense, index);
                    return false;
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: colorScheme.error,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.delete_rounded,
                      color: colorScheme.onError,
                    ),
                  ),
                  child: Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      onTap: () => _editExpense(expense, index),
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primaryContainer,
                        child: Icon(
                          _getCategoryIcon(expense.category),
                          color: colorScheme.onPrimaryContainer,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        expense.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${expense.category} • ${_formatDateTime(expense.date)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Text(
                        '₹${expense.amount}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.primary,
                            ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant_rounded;
      case 'travel':
        return Icons.directions_car_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'entertainment':
        return Icons.movie_rounded;
      case 'bills':
        return Icons.receipt_rounded;
      case 'health':
        return Icons.medical_services_rounded;
      case 'education':
        return Icons.school_rounded;
      case 'savings':
        return Icons.savings_rounded;
      default:
        return Icons.payment_rounded;
    }
  }
}
