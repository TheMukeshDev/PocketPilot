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
  static const Duration _mergeWindow = Duration(minutes: 3);
  late List<Expense> _expenses;

  @override
  void initState() {
    super.initState();
    _expenses = List<Expense>.from(widget.expenses);
  }

  Future<void> _openPayFlow() async {
    final paidExpense = await Navigator.of(context).push<Expense>(
      MaterialPageRoute(builder: (_) => const ScanQrPaymentScreen()),
    );

    if (paidExpense == null || !mounted) {
      return;
    }

    final saved = await ExpenseService.instance.addExpense(
      paidExpense,
      AuthService.instance.currentUser,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _expenses = [saved, ..._expenses];
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

    if (!mounted || action == null) {
      return;
    }

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

    if (newExpense == null || !mounted) {
      return;
    }

    final saved = await ExpenseService.instance.addExpense(
      newExpense,
      AuthService.instance.currentUser,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _expenses = [saved, ..._expenses];
    });
  }

  List<Expense> _mergedHistory() {
    final sorted = List<Expense>.from(_expenses)
      ..sort((a, b) => b.date.compareTo(a.date));

    final merged = <Expense>[];
    for (final candidate in sorted) {
      final duplicateIndex = merged.indexWhere(
        (existing) => _isLikelySameTransaction(existing, candidate),
      );

      if (duplicateIndex == -1) {
        merged.add(candidate);
        continue;
      }

      final existing = merged[duplicateIndex];
      if (_isPreferred(candidate, over: existing)) {
        merged[duplicateIndex] = candidate;
      }
    }

    return merged;
  }

  bool _isLikelySameTransaction(Expense a, Expense b) {
    if (a.amount != b.amount) return false;

    final diff = a.date.difference(b.date).abs();
    if (diff > _mergeWindow) return false;

    final aOnline = _isOnlineExpense(a);
    final bOnline = _isOnlineExpense(b);

    return aOnline && bOnline;
  }

  bool _isPreferred(Expense candidate, {required Expense over}) {
    final candidateTitle = candidate.title.toLowerCase();
    final overTitle = over.title.toLowerCase();

    final candidateIsUpi = candidateTitle.contains('[online] upi');
    final overIsUpi = overTitle.contains('[online] upi');

    if (candidateIsUpi && !overIsUpi) {
      return true;
    }

    if (!candidateIsUpi && overIsUpi) {
      return false;
    }

    return candidate.date.isAfter(over.date);
  }

  bool _isOnlineExpense(Expense expense) {
    final title = expense.title.toLowerCase();
    return title.contains('[online]') ||
        title.contains('[online sms]') ||
        title.contains('upi') ||
        title.contains('debit');
  }

  String _displayTitle(Expense expense) {
    final raw = expense.title.trim();
    if (raw.startsWith('[Online] UPI - ')) {
      final receiver = raw.replaceFirst('[Online] UPI - ', '').trim();
      return 'UPI Payment to $receiver';
    }
    if (raw.startsWith('[Online SMS] ')) {
      return 'SMS Debit • ${raw.replaceFirst('[Online SMS] ', '')}';
    }
    return raw;
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
    final mergedHistory = _mergedHistory();
    final alerts = <String>[
      if (mergedHistory.isNotEmpty)
        'You have ${mergedHistory.length} merged transactions in history.',
      if (mergedHistory.isEmpty)
        'No expenses tracked yet. Start with Scan to Pay.',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense History'),
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
      body: mergedHistory.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No expense history yet.\nYour manual + online + SMS transactions will appear here.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
              itemCount: mergedHistory.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final expense = mergedHistory[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        '₹',
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(
                      _displayTitle(expense),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${expense.category} • ${_formatDateTime(expense.date)}',
                    ),
                    trailing: Text(
                      '₹${expense.amount}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
