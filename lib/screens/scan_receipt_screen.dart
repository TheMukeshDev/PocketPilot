import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/expense.dart';
import '../services/receipt_scanner_service.dart';

enum _ScanState { idle, scanning, results }

class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen>
    with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();

  _ScanState _state = _ScanState.idle;
  File? _pickedImage;
  ScannedReceiptData? _result;

  // Scan line animation
  late final AnimationController _scanLineCtrl;
  late final Animation<double> _scanLineAnim;

  // Result slide-up animation
  late final AnimationController _resultSlideCtrl;
  late final Animation<Offset> _resultSlideAnim;

  // Editable form controllers (populated after scan)
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  String _category = 'Other';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _scanLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scanLineAnim = CurvedAnimation(
      parent: _scanLineCtrl,
      curve: Curves.easeInOut,
    );

    _resultSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _resultSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _resultSlideCtrl,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _scanLineCtrl.dispose();
    _resultSlideCtrl.dispose();
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _dateCtrl.text = _formatDate(picked);
    });
  }

  // ── Pick & scan flow ───────────────────────────────────────────────────────

  Future<void> _pickAndScan(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2048,
    );
    if (picked == null) return;
    if (!mounted) return;

    setState(() {
      _pickedImage = File(picked.path);
      _state = _ScanState.scanning;
    });
    _scanLineCtrl.repeat(reverse: true);

    try {
      final data = await ReceiptScannerService.scanFromPath(picked.path);
      if (!mounted) return;

      _applyResult(data);
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _ScanState.idle);
      _pickedImage = null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scan failed. Please try again with a clearer image.'),
        ),
      );
    }
  }

  void _applyResult(ScannedReceiptData data) {
    _result = data;

    _titleCtrl.text = data.hasTitle ? data.title! : '';
    _amountCtrl.text = data.hasAmount ? data.amount.toString() : '';
    _category = ReceiptScannerService.allCategories.contains(data.category)
        ? data.category
        : 'Other';
    if (data.hasDate) {
      _selectedDate = data.date!;
    } else {
      _selectedDate = DateTime.now();
    }
    _dateCtrl.text = _formatDate(_selectedDate);

    setState(() => _state = _ScanState.results);
    _scanLineCtrl.stop();
    _resultSlideCtrl.forward(from: 0);
  }

  void _rescan() {
    setState(() {
      _state = _ScanState.idle;
      _pickedImage = null;
      _result = null;
      _titleCtrl.clear();
      _amountCtrl.clear();
      _dateCtrl.clear();
      _category = 'Other';
      _selectedDate = DateTime.now();
    });
    _resultSlideCtrl.reset();
  }

  void _saveExpense() {
    if (!_formKey.currentState!.validate()) return;

    final expense = Expense(
      title: _titleCtrl.text.trim(),
      amount: int.parse(_amountCtrl.text.trim()),
      category: _category,
      date: _selectedDate,
    );
    Navigator.of(context).pop(expense);
  }

  // ── Sections ───────────────────────────────────────────────────────────────

  Widget _buildIdleBody(ColorScheme cs) {
    return Column(
      children: [
        const SizedBox(height: 24),

        // ── Hero illustration ─────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          height: 220,
          decoration: BoxDecoration(
            color: cs.primaryContainer.withOpacity(0.25),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: cs.primary.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.document_scanner_rounded,
                size: 72,
                color: cs.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Scan a Receipt or Screenshot',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Auto-detects amount, merchant & category\nautomatically',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withOpacity(0.55),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // ── Tips row ──────────────────────────────────────────────────────
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _TipChip(icon: Icons.wb_sunny_outlined, label: 'Good lighting'),
              SizedBox(width: 8),
              _TipChip(icon: Icons.crop_rounded, label: 'Flat & unfolded'),
              SizedBox(width: 8),
              _TipChip(icon: Icons.hd_rounded, label: 'Sharp focus'),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // ── Action buttons ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: _SourceButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  subtitle: 'Take a photo',
                  color: cs.primary,
                  onTap: () => _pickAndScan(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _SourceButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  subtitle: 'Pick an image',
                  color: cs.secondary,
                  onTap: () => _pickAndScan(ImageSource.gallery),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Supported types ────────────────────────────────────────────────
        Text(
          'Works with receipts · UPI screenshots · bills · invoices',
          style: TextStyle(
            fontSize: 11.5,
            color: cs.onSurface.withOpacity(0.45),
          ),
        ),
      ],
    );
  }

  Widget _buildScanningBody(ColorScheme cs) {
    return Column(
      children: [
        const SizedBox(height: 24),

        // ── Image preview with scan line overlay ──────────────────────────
        Stack(
          alignment: Alignment.topCenter,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: cs.primary.withOpacity(0.6),
                  width: 2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.file(
                _pickedImage!,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),

            // Corner brackets
            ..._buildScanCorners(cs),

            // Scan line
            Positioned(
              left: 24,
              right: 24,
              top: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: _scanLineAnim,
                builder: (_, __) {
                  return Align(
                    alignment: Alignment(0, (_scanLineAnim.value * 2) - 1),
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            cs.primary.withOpacity(0.9),
                            cs.primary,
                            cs.primary.withOpacity(0.9),
                            Colors.transparent,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        const CircularProgressIndicator(),
        const SizedBox(height: 14),
        Text(
          'Reading receipt…',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: cs.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Extracting details from receipt',
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurface.withOpacity(0.55),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildScanCorners(ColorScheme cs) {
    const size = 22.0;
    const thickness = 3.5;
    final color = cs.primary;
    Widget corner({
      double? top,
      double? left,
      double? right,
      double? bottom,
    }) {
      return Positioned(
        top: top != null ? top + 0 : null,
        left: left != null ? left + 24 : null,
        right: right != null ? right + 24 : null,
        bottom: bottom,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _CornerPainter(
              color: color,
              thickness: thickness,
              topLeft: top != null && left != null,
              topRight: top != null && right != null,
              bottomLeft: bottom != null && left != null,
              bottomRight: bottom != null && right != null,
            ),
          ),
        ),
      );
    }

    return [
      corner(top: 0, left: 0),
      corner(top: 0, right: 0),
      corner(bottom: 0, left: 0),
      corner(bottom: 0, right: 0),
    ];
  }

  Widget _buildResultsBody(ColorScheme cs) {
    final result = _result!;
    return SlideTransition(
      position: _resultSlideAnim,
      child: FadeTransition(
        opacity: _resultSlideCtrl,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Scanned image thumbnail ────────────────────────────────
              if (_pickedImage != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  height: 142,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.outline.withOpacity(0.3),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(_pickedImage!, fit: BoxFit.cover),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _ResultBadge(
                          label: result.usedAi ? 'Enhanced' : 'Detected',
                          icon: result.usedAi
                              ? Icons.auto_awesome
                              : Icons.text_fields_rounded,
                          color: result.usedAi ? cs.tertiary : cs.secondary,
                          onBackground: result.usedAi
                              ? cs.onTertiary
                              : cs.onSecondary,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.6),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: Colors.greenAccent, size: 15),
                              const SizedBox(width: 5),
                              const Text(
                                'Scan complete',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _rescan,
                                child: const Text(
                                  'Rescan',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      decoration: TextDecoration.underline),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 14),

              // ── Detected data summary strip ────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: result.hasAmount
                      ? Colors.green.withOpacity(0.08)
                      : cs.errorContainer.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: result.hasAmount
                        ? Colors.green.withOpacity(0.25)
                        : cs.error.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      result.hasAmount
                          ? Icons.check_circle_outline_rounded
                          : Icons.warning_amber_rounded,
                      size: 18,
                      color: result.hasAmount ? Colors.green : cs.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.hasAmount
                            ? 'Detected  ₹${result.amount}  ·  ${result.category}  ·  ${result.hasTitle ? result.title : 'unknown merchant'}'
                            : 'Amount not detected — please fill manually',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: result.hasAmount
                                ? Colors.green[800]
                                : cs.error),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Editable form ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Review & Edit',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withOpacity(0.6),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 20),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: cs.outline.withOpacity(0.2),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _ScanField(
                        label: 'Amount (₹)',
                        icon: Icons.currency_rupee_rounded,
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        detected: result.hasAmount,
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          return (n == null || n <= 0)
                              ? 'Enter a valid amount'
                              : null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _ScanField(
                        label: 'Merchant / Title',
                        icon: Icons.storefront_rounded,
                        controller: _titleCtrl,
                        detected: result.hasTitle,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter a title'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Category dropdown
                      DropdownButtonFormField<String>(
                        value: _category,
                        borderRadius: BorderRadius.circular(14),
                        isExpanded: true,
                        decoration: _fieldDecoration(
                          label: 'Category',
                          icon: Icons.category_rounded,
                          cs: cs,
                          detected: result.category != 'Other',
                        ),
                        items:
                            ReceiptScannerService.allCategories.map((cat) {
                          final emoji =
                              ReceiptScannerService.categoryEmoji[cat] ?? '';
                          return DropdownMenuItem(
                            value: cat,
                            child: Text('$emoji  $cat'),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _category = v);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Date field
                      TextFormField(
                        controller: _dateCtrl,
                        readOnly: true,
                        onTap: _pickDate,
                        decoration: _fieldDecoration(
                          label: 'Date',
                          icon: Icons.calendar_today_rounded,
                          cs: cs,
                          detected: result.hasDate,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Raw OCR text (collapsible) ────────────────────────────
              if (result.rawText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        'Raw OCR Text',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurface.withOpacity(0.55),
                        ),
                      ),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.surfaceVariant.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: SelectableText(
                            result.rawText,
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // ── Save button ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FilledButton.icon(
                  onPressed: _saveExpense,
                  icon: const Icon(Icons.save_alt_rounded),
                  label: const Text('Save Expense'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: OutlinedButton.icon(
                  onPressed: _rescan,
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Scan Again'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    required ColorScheme cs,
    bool detected = false,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon,
          color: detected ? cs.primary : cs.onSurface.withOpacity(0.4)),
      filled: true,
      fillColor: detected
          ? cs.primaryContainer.withOpacity(0.18)
          : cs.surfaceVariant.withOpacity(0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: detected
            ? BorderSide(color: cs.primary.withOpacity(0.3), width: 1)
            : BorderSide.none,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Receipt'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'How it works',
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: _state == _ScanState.scanning
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          child: switch (_state) {
            _ScanState.idle => _buildIdleBody(cs),
            _ScanState.scanning => _buildScanningBody(cs),
            _ScanState.results => _buildResultsBody(cs),
          },
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How Add Receipt Works'),
        contentPadding:
            const EdgeInsets.fromLTRB(20, 16, 20, 0),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HelpStep(
              icon: Icons.camera_alt_rounded,
              text: 'Photograph a receipt, UPI screenshot, or any bill.',
            ),
            _HelpStep(
              icon: Icons.text_fields_rounded,
              text:
              'On-device OCR extracts receipt text instantly.',
            ),
            _HelpStep(
              icon: Icons.auto_awesome,
              text:
              'Smart detection fills gaps in amount, merchant, and category.',
            ),
            _HelpStep(
              icon: Icons.edit_rounded,
              text: 'Review and edit any field before saving.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: color.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TipChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(0.6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: cs.primary),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                color: cs.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color onBackground;
  const _ResultBadge(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onBackground});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: onBackground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: onBackground,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool detected;
  final String? Function(String?)? validator;

  const _ScanField({
    required this.label,
    required this.icon,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.detected = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon,
            color: detected ? cs.primary : cs.onSurface.withOpacity(0.4)),
        filled: true,
        fillColor: detected
            ? cs.primaryContainer.withOpacity(0.18)
            : cs.surfaceVariant.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: detected
              ? BorderSide(color: cs.primary.withOpacity(0.3), width: 1)
              : BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

class _HelpStep extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HelpStep({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13.5, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

// ── Corner painter for viewfinder ────────────────────────────────────────────

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;

  const _CornerPainter({
    required this.color,
    required this.thickness,
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const len = 20.0;
    if (topLeft) {
      canvas.drawLine(Offset.zero, const Offset(len, 0), paint);
      canvas.drawLine(Offset.zero, const Offset(0, len), paint);
    }
    if (topRight) {
      canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint);
      canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);
    }
    if (bottomLeft) {
      canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);
      canvas.drawLine(
          Offset(0, size.height), Offset(0, size.height - len), paint);
    }
    if (bottomRight) {
      canvas.drawLine(Offset(size.width, size.height),
          Offset(size.width - len, size.height), paint);
      canvas.drawLine(Offset(size.width, size.height),
          Offset(size.width, size.height - len), paint);
    }
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.color != color;
}
