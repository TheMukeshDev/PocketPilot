import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/expense.dart';
import '../services/payment_service.dart';
import 'payment_screen.dart';

class ScanQrPaymentScreen extends StatefulWidget {
  const ScanQrPaymentScreen({super.key});

  @override
  State<ScanQrPaymentScreen> createState() => _ScanQrPaymentScreenState();
}

class _ScanQrPaymentScreenState extends State<ScanQrPaymentScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );

  final TextEditingController _upiIdController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  static const List<String> _expenseCategories = <String>[
    'Investment',
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

  String _selectedCategory = 'Other';
  String? _originalUpiUri;

  bool _torchEnabled = false;
  bool _isHandlingScan = false;
  bool _isQrDetected = false;
  bool _isCameraStarted = true;

  @override
  void dispose() {
    _scannerController.dispose();
    _upiIdController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isHandlingScan || _isQrDetected) {
      return;
    }

    final value = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim() ?? '')
        .firstWhere((raw) => raw.isNotEmpty, orElse: () => '');

    if (value.isEmpty) {
      return;
    }

    _isHandlingScan = true;
    final parsed = PaymentService.instance.parseUpiQrData(value);

    if (parsed == null) {
      _isHandlingScan = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This QR is not a valid UPI payment QR.')),
      );
      return;
    }

    _upiIdController.text = parsed.receiverUpiId;
    _amountController.text = parsed.amount?.toStringAsFixed(0) ?? '';
    _originalUpiUri = parsed.originalUpiUri;

    await _scannerController.stop();

    if (!mounted) return;
    setState(() {
      _isQrDetected = true;
      _isCameraStarted = false;
    });

    _isHandlingScan = false;
  }

  Future<void> _toggleTorch() async {
    await _scannerController.toggleTorch();
    if (!mounted) return;
    setState(() => _torchEnabled = !_torchEnabled);
  }

  Future<void> _scanAgain() async {
    setState(() {
      _isQrDetected = false;
      _isCameraStarted = true;
      _isHandlingScan = false;
      _originalUpiUri = null;
    });
    await _scannerController.start();
  }

  Future<void> _proceedToPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.parse(_amountController.text.trim());

    final paidExpense = await Navigator.of(context).push<Expense>(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          amount: amount,
          receiverName: 'UPI Merchant',
          receiverUpiId: _upiIdController.text.trim(),
          transactionNote: 'QR Payment',
          expenseCategory: _selectedCategory,
          originalUpiUri: _originalUpiUri,
        ),
      ),
    );

    if (paidExpense == null || !mounted) {
      return;
    }

    Navigator.of(context).pop(paidExpense);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR & Pay'),
        actions: [
          IconButton(
            onPressed: _toggleTorch,
            icon: Icon(
              _torchEnabled ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: 280,
                child: _isCameraStarted
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          MobileScanner(
                            controller: _scannerController,
                            onDetect: _onDetect,
                          ),
                          Align(
                            alignment: Alignment.center,
                            child: Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: colorScheme.primary,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 12,
                            child: Text(
                              'Align UPI QR in the frame',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Container(
                        color: colorScheme.surfaceVariant,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.qr_code_scanner_rounded,
                              size: 42,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'QR detected successfully',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _isQrDetected
                  ? 'UPI ID detected. Confirm amount and continue.'
                  : 'Scan a UPI QR code to auto-fill UPI ID.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _upiIdController,
                    decoration: const InputDecoration(
                      labelText: 'UPI ID',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    validator: (value) {
                      final upiId = value?.trim() ?? '';
                      if (upiId.isEmpty) {
                        return 'UPI ID is required';
                      }
                      if (!PaymentService.instance.isValidUpiId(upiId)) {
                        return 'Enter a valid UPI ID (example@upi)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixIcon: Icon(Icons.currency_rupee_rounded),
                    ),
                    validator: (value) {
                      final amount = double.tryParse(value?.trim() ?? '');
                      if (amount == null || amount <= 0) {
                        return 'Enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Expense Category',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _expenseCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, index) {
                        final category = _expenseCategories[index];
                        final selected = _selectedCategory == category;
                        return ChoiceChip(
                          label: Text(category),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = category),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_isQrDetected)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _scanAgain,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Scan Again'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _proceedToPayment,
                      icon: const Icon(Icons.account_balance_wallet_rounded),
                      label: const Text('Choose UPI App'),
                    ),
                  ),
                ],
              )
            else
              FilledButton.icon(
                onPressed: _proceedToPayment,
                icon: const Icon(Icons.account_balance_wallet_rounded),
                label: const Text('Choose UPI App'),
              ),
          ],
        ),
      ),
    );
  }
}
