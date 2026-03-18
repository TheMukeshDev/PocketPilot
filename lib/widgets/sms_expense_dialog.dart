import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../services/sms_expense_parser.dart';

/// Confirmation dialog shown when a transaction SMS is auto-detected.
///
/// Lets the user review/edit the titre, amount, and category before
/// saving, or dismiss the suggestion entirely.
class SmsExpenseDialog extends StatefulWidget {
  const SmsExpenseDialog({super.key, required this.data});

  final SmsExpenseData data;

  @override
  State<SmsExpenseDialog> createState() => _SmsExpenseDialogState();
}

class _SmsExpenseDialogState extends State<SmsExpenseDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late String _selectedCategory;

  static const List<String> _categories = [
    'Food',
    'Travel',
    'Shopping',
    'Health',
    'Entertainment',
    'Bills',
    'Study',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.data.title);
    _amountController =
        TextEditingController(text: widget.data.amount.toString());
    _selectedCategory = _categories.contains(widget.data.category)
        ? widget.data.category
        : 'Other';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onAdd() {
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount.')),
      );
      return;
    }

    final expense = Expense(
      title: _titleController.text.trim().isEmpty
          ? 'Auto Detected'
          : _titleController.text.trim(),
      amount: amount,
      category: _selectedCategory,
      date: DateTime.now(),
    );

    Navigator.of(context).pop(expense);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: Icon(Icons.sms_rounded, color: colorScheme.primary, size: 28),
      title: const Text('Auto Detected Expense'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 16, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'A bank transaction was detected from your SMS. Review and save.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Merchant / Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.store_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee_rounded),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category_rounded),
              ),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedCategory = v);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Ignore'),
        ),
        FilledButton.icon(
          onPressed: _onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Expense'),
        ),
      ],
    );
  }
}
