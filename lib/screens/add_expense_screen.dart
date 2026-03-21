import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/expense.dart';
import '../services/receipt_scanner_service.dart';
import 'scan_receipt_screen.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  String _category = 'Food';
  DateTime _selectedDate = DateTime.now();
  bool _isScanning = false;

  // Full category list from scanner service (covers all OCR/AI detections).
  List<String> get _categories => ReceiptScannerService.allCategories;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _dateController.text = _formatDate(_selectedDate);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 1),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = picked;
      _dateController.text = _formatDate(picked);
    });
  }

  // ─── Scan flow ────────────────────────────────────────────────────────────

  /// Picks an image then runs the scanner service.
  Future<void> _pickAndScan(ImageSource source) async {
    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2048,
    );
    if (image == null) return;
    if (!mounted) return;

    setState(() => _isScanning = true);
    try {
      final scanned = await ReceiptScannerService.scanFromPath(image.path);
      if (!mounted) return;

      if (!scanned.hasAmount && !scanned.hasTitle) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not read receipt clearly. Please enter details manually.'),
          ),
        );
        return;
      }

      _showReviewSheet(scanned);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Receipt scan failed. You can still add expense manually.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  // ignore: unused_element
  Future<void> _openImageSourcePicker() async {
    if (_isScanning) {
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
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
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Capture from Camera'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Pick from Gallery'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );

    if (source != null) {
      await _pickAndScan(source);
    }
  }

  /// Bottom sheet showing extracted data for review before applying.
  void _showReviewSheet(ScannedReceiptData data) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Scan Results',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (data.usedAi)
                      Chip(
                        label: const Text(
                          'Enhanced Detection',
                          style: TextStyle(fontSize: 11),
                        ),
                        avatar: const Icon(Icons.auto_awesome, size: 14),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        backgroundColor:
                            Theme.of(ctx).colorScheme.tertiaryContainer,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  data.hasAmount
                      ? 'Review the extracted data — tap Apply to fill the form.'
                      : 'Amount not detected. Fill manually or try a clearer image.',
                  style: TextStyle(
                    fontSize: 12,
                    color: data.hasAmount
                        ? Colors.grey[600]
                        : Theme.of(ctx).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 20),
                _DetectedField(
                  icon: Icons.currency_rupee_rounded,
                  label: 'Amount',
                  value: data.hasAmount ? '₹${data.amount}' : 'Not detected',
                  found: data.hasAmount,
                  highlight: true,
                ),
                const SizedBox(height: 10),
                _DetectedField(
                  icon: Icons.storefront_rounded,
                  label: 'Merchant / Title',
                  value: data.hasTitle ? data.title! : 'Not detected',
                  found: data.hasTitle,
                ),
                const SizedBox(height: 10),
                _DetectedField(
                  icon: Icons.category_rounded,
                  label: 'Category',
                  value:
                      '${ReceiptScannerService.categoryEmoji[data.category] ?? ''} ${data.category}',
                  found: data.category != 'Other',
                ),
                const SizedBox(height: 10),
                _DetectedField(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date',
                  value:
                      data.hasDate ? _formatDate(data.date!) : 'Not detected',
                  found: data.hasDate,
                ),
                const SizedBox(height: 16),
                if (data.rawText.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text(
                      'Raw OCR Text',
                      style: TextStyle(fontSize: 13),
                    ),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SelectableText(
                          data.rawText,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _applyScannedData(data);
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Apply to Form'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Discard'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Fills the form with scan results.
  void _applyScannedData(ScannedReceiptData data) {
    setState(() {
      if (data.hasAmount) {
        _amountController.text = data.amount.toString();
      }
      if (data.hasTitle) {
        _titleController.text = data.title!;
      }
      if (_categories.contains(data.category)) {
        _category = data.category;
      }
      if (data.hasDate) {
        _selectedDate = data.date!;
        _dateController.text = _formatDate(data.date!);
      }
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          data.usedAi
              ? 'Auto-filled using AI — please verify'
              : 'Auto-filled from scan — please verify',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _saveExpense() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final expense = Expense(
      title: _titleController.text.trim(),
      amount: int.parse(_amountController.text.trim()),
      category: _category,
      date: _selectedDate,
    );

    Navigator.of(context).pop(expense);
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight - 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Receipt scan banner ─────────────────────────────────
                      Card(
                        elevation: 0,
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withOpacity(0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.25),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.document_scanner_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Auto-fill from Receipt',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Use camera or gallery image to auto-fill fields',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _isScanning
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : FilledButton.tonal(
                                      onPressed: () async {
                                        final scanned =
                                            await Navigator.of(context)
                                                .push<Expense>(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ScanReceiptScreen(),
                                          ),
                                        );
                                        if (scanned != null && mounted) {
                                          setState(() {
                                            if (scanned.amount > 0) {
                                              _amountController.text =
                                                  scanned.amount.toString();
                                            }
                                            if (scanned.title.isNotEmpty) {
                                              _titleController.text =
                                                  scanned.title;
                                            }
                                            if (_categories
                                                .contains(scanned.category)) {
                                              _category = scanned.category;
                                            }
                                            _selectedDate = scanned.date;
                                            _dateController.text =
                                                _formatDate(scanned.date);
                                          });
                                        }
                                      },
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: const Text('Scan Receipt'),
                                    ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Expense details card ────────────────────────────
                      Card(
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _titleController,
                                textInputAction: TextInputAction.next,
                                decoration: _inputDecoration(
                                  label: 'Expense Title',
                                  icon: Icons.drive_file_rename_outline_rounded,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter an expense title';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _amountController,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                decoration: _inputDecoration(
                                  label: 'Amount',
                                  icon: Icons.currency_rupee_rounded,
                                ),
                                validator: (value) {
                                  final amount =
                                      int.tryParse(value?.trim() ?? '');
                                  if (amount == null || amount <= 0) {
                                    return 'Enter a valid amount';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _category,
                                borderRadius: BorderRadius.circular(14),
                                isExpanded: true,
                                items: _categories.map((item) {
                                  final emoji = ReceiptScannerService
                                          .categoryEmoji[item] ??
                                      '';
                                  return DropdownMenuItem<String>(
                                    value: item,
                                    child: Text('$emoji  $item'),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setState(() {
                                    _category = value;
                                  });
                                },
                                decoration: _inputDecoration(
                                  label: 'Category',
                                  icon: Icons.category_rounded,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _dateController,
                                readOnly: true,
                                onTap: _pickDate,
                                decoration: _inputDecoration(
                                  label: 'Date',
                                  icon: Icons.calendar_today_rounded,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _saveExpense,
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Save Expense'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Detected field card (inside review sheet) ────────────────────────────────

class _DetectedField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool found;
  final bool highlight;

  const _DetectedField({
    required this.icon,
    required this.label,
    required this.value,
    required this.found,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: found
            ? (highlight
                ? cs.primaryContainer.withOpacity(0.55)
                : cs.surfaceVariant)
            : cs.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: found && highlight
              ? cs.primary.withOpacity(0.4)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: found ? cs.primary : cs.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: cs.outline),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: found ? FontWeight.w600 : FontWeight.normal,
                        color: found ? cs.onSurface : cs.outline,
                        fontSize: highlight && found ? 16 : null,
                      ),
                ),
              ],
            ),
          ),
          Icon(
            found ? Icons.check_circle_rounded : Icons.help_outline_rounded,
            size: 16,
            color: found ? cs.primary : cs.outline,
          ),
        ],
      ),
    );
  }
}
