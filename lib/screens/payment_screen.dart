import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/expense.dart';
import '../services/payment_service.dart';
import '../utils/upi_payment_validation.dart';
import '../widgets/payment_app_card.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.amount,
    required this.receiverName,
    required this.receiverUpiId,
    required this.transactionNote,
    this.expenseCategory = 'Other',
    this.originalUpiUri,
  });

  final double amount;
  final String receiverName;
  final String receiverUpiId;
  final String transactionNote;
  final String expenseCategory;
  final String? originalUpiUri;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  List<PaymentLaunchApp> _upiApps = const <PaymentLaunchApp>[];
  bool _isLoadingApps = true;
  bool _isProcessingPayment = false;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _upiIdController;
  late final TextEditingController _receiverNameController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _upiIdController = TextEditingController(text: widget.receiverUpiId.trim());
    _receiverNameController = TextEditingController(text: widget.receiverName.trim());
    _amountController = TextEditingController(text: widget.amount.toStringAsFixed(2));
    _noteController = TextEditingController(text: widget.transactionNote.trim());
    _loadUpiApps();
  }

  @override
  void dispose() {
    _upiIdController.dispose();
    _receiverNameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadUpiApps() async {
    final apps = await PaymentService.instance.getInstalledUpiApps();
    if (!mounted) {
      return;
    }
    setState(() {
      _upiApps = apps;
      _isLoadingApps = false;
    });
  }

  Future<void> _payWithApp(PaymentLaunchApp app) async {
    final validated = await _ensureReadyForPayment();
    if (validated == null) {
      return;
    }

    setState(() => _isProcessingPayment = true);

    PaymentResult result;
    try {
      result = await PaymentService.instance.initiatePayment(
        app: app,
        receiverUpiId: validated.upiId,
        receiverName: validated.receiverName,
        amount: validated.amount,
        transactionNote: validated.note,
        originalUpiUri: widget.originalUpiUri,
      );
    } catch (_) {
      result = const PaymentResult(
        status: PaymentStatus.failure,
        message: 'Unable to open payment app right now. Please try again.',
      );
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }

    if (!mounted) {
      return;
    }

    if (result.status == PaymentStatus.failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      await _showPaymentFallbackSheet(validated);
      return;
    }

    final shouldRecordExpense = await _showResultDialog(result);

    if (!mounted || !shouldRecordExpense) {
      return;
    }

    _recordPaidExpense();
  }

  Future<void> _payWithAnyUpiApp() async {
    final validated = await _ensureReadyForPayment();
    if (validated == null) {
      return;
    }

    setState(() => _isProcessingPayment = true);

    PaymentResult result;
    try {
      result = await PaymentService.instance.launchPaymentWithAnyUpiApp(
        receiverUpiId: validated.upiId,
        receiverName: validated.receiverName,
        amount: validated.amount,
        transactionNote: validated.note,
        originalUpiUri: widget.originalUpiUri,
      );
    } catch (_) {
      result = const PaymentResult(
        status: PaymentStatus.failure,
        message: 'Unable to open UPI chooser right now. Please try again.',
      );
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }

    if (!mounted) {
      return;
    }

    if (result.status == PaymentStatus.failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open chooser. You can copy UPI ID and pay manually.'),
        ),
      );
      await _showPaymentFallbackSheet(validated);
      return;
    }

    final shouldRecordExpense = await _showResultDialog(result);
    if (!mounted || !shouldRecordExpense) {
      return;
    }

    _recordPaidExpense();
  }

  void _recordPaidExpense() {
    final amount = double.tryParse(_amountController.text.trim()) ?? widget.amount;
    final upiId = _upiIdController.text.trim();
    Navigator.of(context).pop(
      Expense(
        title: '[Online] UPI - $upiId',
        category: widget.expenseCategory,
        amount: amount.round(),
        date: DateTime.now(),
      ),
    );
  }

  Future<bool> _showResultDialog(PaymentResult result) async {
    final colorScheme = Theme.of(context).colorScheme;

    String title;
    IconData icon;
    Color iconColor;

    switch (result.status) {
      case PaymentStatus.success:
        title = 'Payment Successful 🎉';
        icon = Icons.check_circle_rounded;
        iconColor = colorScheme.primary;
        break;
      case PaymentStatus.submitted:
        title = 'Payment Pending / Submitted';
        icon = Icons.schedule_rounded;
        iconColor = colorScheme.tertiary;
        break;
      case PaymentStatus.failure:
        title = 'Payment Failed';
        icon = Icons.error_rounded;
        iconColor = colorScheme.error;
        break;
    }

    final shouldRecord = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(icon, color: iconColor, size: 36),
        title: Text(title),
        content: Text(
          result.status == PaymentStatus.success
              ? '₹${widget.amount.toStringAsFixed(0)} sent successfully.'
              : result.status == PaymentStatus.submitted
                  ? '${result.message}\n\nIf money is debited in your UPI app, tap "Mark as Paid" to save it in spending history.'
                  : result.message,
        ),
        actions: result.status == PaymentStatus.submitted
            ? [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Not Yet'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Mark as Paid'),
                ),
              ]
            : [
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(result.isSuccessful),
                  child: const Text('OK'),
                ),
              ],
      ),
    );

    if (result.status != PaymentStatus.submitted) {
      return shouldRecord ?? false;
    }

    if (shouldRecord == true) {
      return true;
    }

    if (!mounted) {
      return false;
    }

    final deducted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Did amount get deducted?'),
        content: const Text(
          'If the money is already deducted in your UPI app, add it now to payment history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, Add Now'),
          ),
        ],
      ),
    );

    return deducted ?? false;
  }

  Future<UpiPaymentValidationResult?> _ensureReadyForPayment() async {
    final hasInternet = await _hasInternetConnection();
    if (!mounted) {
      return null;
    }

    if (!hasInternet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Connect and try again.'),
        ),
      );
      return null;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the highlighted fields.')),
      );
      return null;
    }

    return UpiPaymentValidators.buildValidatedInput(
      upiId: _upiIdController.text,
      receiverName: _receiverNameController.text,
      amountText: _amountController.text,
      note: _noteController.text,
    );
  }

  Future<bool> _hasInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _showHowUpiWorksSheet() async {
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How UPI Payment Works',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            const Text('1. Enter valid UPI ID, receiver name, amount'),
            const SizedBox(height: 6),
            const Text('2. Choose your payment app (or use the chooser)'),
            const SizedBox(height: 6),
            const Text('3. Complete payment in the selected app'),
            const SizedBox(height: 6),
            const Text('4. Return to PocketPilot after payment'),
            const SizedBox(height: 14),
            Text(
              'Note: Some UPI apps may reject requests depending on their internal policies. If one app fails, try the chooser or another installed UPI app.',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPaymentFallbackSheet(UpiPaymentValidationResult validated) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment options',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.apps_rounded),
              title: const Text('Try chooser'),
              subtitle: const Text('Let Android show all UPI apps'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await _payWithAnyUpiApp();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy UPI ID'),
              subtitle: Text(validated.upiId),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: validated.upiId));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('UPI ID copied to clipboard.')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_rounded),
              title: const Text('Copy payment note'),
              subtitle: Text(validated.note),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: validated.note));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment note copied to clipboard.')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('Open payment instructions'),
              subtitle: const Text('How to complete UPI payment safely'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await _showHowUpiWorksSheet();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final amountPreview = double.tryParse(_amountController.text.trim()) ?? widget.amount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('UPI Payment'),
        actions: [
          IconButton(
            onPressed: _showHowUpiWorksSheet,
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'How UPI payment works',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isProcessingPayment)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pay ₹${amountPreview.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'UPI Payment',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(_upiIdController.text.trim().isEmpty
                        ? 'Enter details below'
                        : _upiIdController.text.trim()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Form(
              key: _formKey,
              autovalidateMode: _autovalidateMode,
              child: Column(
                children: [
                  TextFormField(
                    controller: _upiIdController,
                    decoration: const InputDecoration(
                      labelText: 'Receiver UPI ID',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: UpiPaymentValidators.validateUpiId,
                    enabled: !_isProcessingPayment,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _receiverNameController,
                    decoration: const InputDecoration(
                      labelText: 'Receiver Name',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: UpiPaymentValidators.validateReceiverName,
                    enabled: !_isProcessingPayment,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixIcon: Icon(Icons.currency_rupee_rounded),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: UpiPaymentValidators.validateAmount,
                    enabled: !_isProcessingPayment,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                    ),
                    textInputAction: TextInputAction.done,
                    enabled: !_isProcessingPayment,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Payment App',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    Icons.apps_rounded,
                    color: colorScheme.primary,
                  ),
                ),
                title: const Text('UPI Apps (Chooser)'),
                subtitle: const Text('Most reliable option if an app fails'),
                trailing: _isProcessingPayment
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: _isProcessingPayment ? null : _payWithAnyUpiApp,
              ),
            ),
            const SizedBox(height: 10),
            if (_isLoadingApps)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_upiApps.isEmpty)
              const Card(
                child: ListTile(
                  title: Text('No UPI apps detected'),
                  subtitle: Text('Try the chooser above, or pay manually using UPI ID.'),
                  enabled: false,
                ),
              )
            else
              ..._upiApps.map(
                (app) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PaymentAppCard(
                    app: app,
                    title: PaymentService.instance.displayNameForApp(app),
                    subtitle: PaymentService.instance.subtitleForApp(app),
                    isProcessing: _isProcessingPayment,
                    onTap: () => _payWithApp(app),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}