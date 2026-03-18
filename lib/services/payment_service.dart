import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:upi_india/upi_india.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/upi_payment_validation.dart';

enum PaymentStatus {
  success,
  failure,
  submitted,
}

class ParsedUpiQrData {
  const ParsedUpiQrData({
    required this.receiverUpiId,
    required this.receiverName,
    this.amount,
    this.note,
    this.originalUpiUri,
  });

  final String receiverUpiId;
  final String receiverName;
  final double? amount;
  final String? note;
  final String? originalUpiUri;
}

class PaymentResult {
  const PaymentResult({
    required this.status,
    required this.message,
  });

  final PaymentStatus status;
  final String message;

  bool get isSuccessful => status == PaymentStatus.success;
}

class PaymentLaunchApp {
  const PaymentLaunchApp({
    required this.name,
    required this.packageName,
    required this.icon,
  });

  final String name;
  final String packageName;
  final Uint8List icon;
}

class PaymentService {
  PaymentService._();

  static final PaymentService instance = PaymentService._();
  static const MethodChannel _platformChannel = MethodChannel(
    'pocketpilot/platform',
  );

  // Enable extra debug logging in debug builds.
  static const bool _debugLogging = true;

  final UpiIndia _upiIndia = UpiIndia();

  static void _log(String message) {
    if (_debugLogging && kDebugMode) {
      debugPrint('[UPI Payment] $message');
    }
  }

  bool isValidUpiId(String value) =>
      UpiPaymentValidators.upiIdPattern.hasMatch(value.trim());

  ParsedUpiQrData? parseUpiQrData(String rawValue) {
    final raw = rawValue.trim();
    if (raw.isEmpty) {
      return null;
    }

    if (UpiPaymentValidators.upiIdPattern.hasMatch(raw)) {
      return ParsedUpiQrData(
        receiverUpiId: raw,
        receiverName: 'UPI Merchant',
      );
    }

    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme.toLowerCase() != 'upi') {
      return null;
    }

    final host = uri.host.toLowerCase();
    if (host != 'pay') {
      return null;
    }

    final upiId = (uri.queryParameters['pa'] ?? '').trim();
    if (!UpiPaymentValidators.upiIdPattern.hasMatch(upiId)) {
      return null;
    }

    final name = (uri.queryParameters['pn'] ?? '').trim();
    final amountRaw = (uri.queryParameters['am'] ?? '').trim();
    final note = (uri.queryParameters['tn'] ?? '').trim();

    final parsedAmount = amountRaw.isEmpty ? null : double.tryParse(amountRaw);

    return ParsedUpiQrData(
      receiverUpiId: upiId,
      receiverName: name.isEmpty ? 'UPI Merchant' : name,
      amount: parsedAmount != null && parsedAmount > 0 ? parsedAmount : null,
      note: note.isEmpty ? null : note,
      originalUpiUri: raw,
    );
  }

  Future<List<PaymentLaunchApp>> getInstalledUpiApps() async {
    if (!Platform.isAndroid) {
      return const <PaymentLaunchApp>[];
    }

    final systemApps = await _loadSystemUpiApps();
    if (systemApps.isNotEmpty) {
      return systemApps;
    }

    return _loadPluginUpiApps();
  }

  Future<List<PaymentLaunchApp>> _loadSystemUpiApps() async {
    try {
      final rawApps = await _platformChannel.invokeListMethod<dynamic>(
        'getAvailableUpiApps',
      );
      if (rawApps == null || rawApps.isEmpty) {
        return const <PaymentLaunchApp>[];
      }

      final apps = <PaymentLaunchApp>[];
      for (final raw in rawApps) {
        if (raw is! Map) {
          continue;
        }

        final packageName = (raw['packageName'] ?? '').toString().trim();
        final name = (raw['name'] ?? '').toString().trim();
        final iconBase64 = (raw['icon'] ?? '').toString().trim();

        if (packageName.isEmpty || name.isEmpty || iconBase64.isEmpty) {
          continue;
        }

        try {
          apps.add(
            PaymentLaunchApp(
              name: name,
              packageName: packageName,
              icon: base64Decode(iconBase64),
            ),
          );
        } catch (_) {
          continue;
        }
      }

      final seen = <String>{};
      final deduped = apps.where((app) => seen.add(app.packageName)).toList();
      deduped.sort((a, b) => _orderRank(a).compareTo(_orderRank(b)));
      return deduped;
    } catch (_) {
      return const <PaymentLaunchApp>[];
    }
  }

  Future<List<PaymentLaunchApp>> _loadPluginUpiApps() async {
    try {
      final upiApps = await _upiIndia.getAllUpiApps(
        mandatoryTransactionId: false,
        allowNonVerifiedApps: true,
      );

      final converted = upiApps
          .map(
            (app) => PaymentLaunchApp(
              name: app.name,
              packageName: app.packageName,
              icon: app.icon,
            ),
          )
          .toList();
      converted.sort((a, b) => _orderRank(a).compareTo(_orderRank(b)));
      return converted;
    } catch (_) {
      return const <PaymentLaunchApp>[];
    }
  }

  Future<PaymentResult> launchPaymentWithAnyUpiApp({
    required String receiverUpiId,
    required String receiverName,
    required double amount,
    required String transactionNote,
    String? originalUpiUri,
  }) async {
    final normalizedUpiId = UpiPaymentValidators.normalizeUpiId(receiverUpiId);
    if (!isValidUpiId(normalizedUpiId)) {
      return const PaymentResult(
        status: PaymentStatus.failure,
        message: 'Invalid UPI ID format. Please check and try again.',
      );
    }

    if (amount <= 0) {
      return const PaymentResult(
        status: PaymentStatus.failure,
        message: 'Amount should be greater than zero.',
      );
    }

    final paymentUri = buildUpiUri(
      receiverUpiId: normalizedUpiId,
      receiverName: receiverName,
      amount: amount,
      transactionNote: transactionNote,
    );

    _log('Validated input: pa=$normalizedUpiId, pn=${receiverName.trim()}, am=${amount.toStringAsFixed(2)}');
    _log('Generated UPI URI: ${paymentUri.toString()}');

    // Primary: url_launcher implicit external app (Android chooser).
    final launchedWithChooser = await _launchExternal(paymentUri);
    if (launchedWithChooser) {
      return const PaymentResult(
        status: PaymentStatus.submitted,
        message: 'Opened UPI app chooser. Complete payment and return to confirm.',
      );
    }

    // Secondary: native intent chooser via platform channel.
    final launchedNativeChooser = await _launchWithPackage(
      uri: paymentUri,
      packageName: '',
    );
    if (launchedNativeChooser) {
      return const PaymentResult(
        status: PaymentStatus.submitted,
        message: 'Opened UPI app chooser. Complete payment and return to confirm.',
      );
    }

    return const PaymentResult(
      status: PaymentStatus.failure,
      message: 'No compatible UPI app found to handle payment intent.',
    );
  }

  Future<PaymentResult> initiatePayment({
    required PaymentLaunchApp app,
    required String receiverUpiId,
    required String receiverName,
    required double amount,
    required String transactionNote,
    String? originalUpiUri,
  }) async {
    final normalizedUpiId = UpiPaymentValidators.normalizeUpiId(receiverUpiId);
    if (!isValidUpiId(normalizedUpiId)) {
      return const PaymentResult(
        status: PaymentStatus.failure,
        message: 'Invalid UPI ID format. Please check and try again.',
      );
    }

    if (amount <= 0) {
      return const PaymentResult(
        status: PaymentStatus.failure,
        message: 'Amount should be greater than zero.',
      );
    }

    final packageName = app.packageName.trim();
    final paymentUri = buildUpiUri(
      receiverUpiId: normalizedUpiId,
      receiverName: receiverName,
      amount: amount,
      transactionNote: transactionNote,
    );

    _log('Selected app: ${app.name} ($packageName)');
    _log('Generated UPI URI: ${paymentUri.toString()}');

    // Step 1: Try launching the specific app (secondary convenience; may fail per-app policies)
    final launchedWithPackage = await _launchWithPackage(
      uri: paymentUri,
      packageName: packageName,
    );

    if (launchedWithPackage) {
      return PaymentResult(
        status: PaymentStatus.submitted,
        message: '${app.name} opened. Complete payment and return to confirm.',
      );
    }

    // Step 2: If specific app fails, try the chooser (primary safe fallback)
    final launchedWithChooser = await _launchExternal(paymentUri);
    if (launchedWithChooser) {
      return const PaymentResult(
        status: PaymentStatus.submitted,
        message: 'Opened UPI app chooser. Select another app and complete payment.',
      );
    }

    // Step 3: Last resort - native chooser intent
    final launchedNativeChooser = await _launchWithPackage(
      uri: paymentUri,
      packageName: '',
    );
    if (launchedNativeChooser) {
      return const PaymentResult(
        status: PaymentStatus.submitted,
        message: 'Opened UPI app chooser. Select another app and complete payment.',
      );
    }

    return const PaymentResult(
      status: PaymentStatus.failure,
      message:
          'This app could not open the payment request. Please try the chooser.',
    );
  }

  Uri buildUpiUri({
    required String receiverUpiId,
    required String receiverName,
    required double amount,
    required String transactionNote,
  }) {
    final pa = UpiPaymentValidators.normalizeUpiId(receiverUpiId);
    final pn = UpiPaymentValidators.normalizeDisplayText(
      receiverName,
      fallback: 'UPI Merchant',
    );
    final tn = UpiPaymentValidators.normalizeDisplayText(
      transactionNote,
      fallback: 'PocketPilot Payment',
    );

    final queryParameters = <String, String>{
      'pa': pa,
      'pn': pn,
      'am': amount.toStringAsFixed(2),
      'cu': 'INR',
      'tn': tn,
    };

    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: queryParameters,
    );

    _log('Final UPI URI: ${uri.toString()}');
    return uri;
  }

  Future<bool> _launchExternal(Uri uri) async {
    try {
      final canLaunch = await canLaunchUrl(uri);
      _log('canLaunchUrl=$canLaunch uri=${uri.toString()}');

      // Even if canLaunchUrl is false (package visibility quirks), attempt launch.
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      _log('launchUrl returned: $launched');
      return launched;
    } catch (e) {
      _log('launchUrl threw: $e');
      return false;
    }
  }

  Future<bool> _launchWithPackage({
    required Uri uri,
    required String packageName,
  }) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final uriString = uri.toString();
      _log('Launching UPI URI: $uriString with package: $packageName');

      final launched = await _platformChannel.invokeMethod<bool>(
        'launchUpiIntent',
        <String, Object?>{
          'uri': uriString,
          'packageName': packageName,
        },
      );
      _log('launchUpiIntent returned: $launched');
      return launched ?? false;
    } on PlatformException catch (e) {
      _log('PlatformException in _launchWithPackage: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      _log('Exception in _launchWithPackage: $e');
      return false;
    }
  }

  int _orderRank(PaymentLaunchApp app) {
    final packageName = app.packageName.toLowerCase();
    final name = app.name.toLowerCase();

    if (packageName.contains('google') || name.contains('gpay')) return 1;
    if (packageName.contains('phonepe') || name.contains('phonepe')) return 2;
    if (packageName.contains('paytm') || name.contains('paytm')) return 3;
    if (packageName.contains('amazon') || name.contains('amazon')) return 4;
    if (packageName.contains('navi') || name.contains('navi')) return 5;
    return 100;
  }

  String displayNameForApp(PaymentLaunchApp app) {
    final packageName = app.packageName.toLowerCase();
    final name = app.name.trim();

    if (packageName.contains('google') || name.toLowerCase().contains('google pay')) {
      return 'GPay';
    }
    if (packageName.contains('amazon') || name.toLowerCase().contains('amazon')) {
      return 'Amazon Pay UPI';
    }
    return name;
  }

  String subtitleForApp(PaymentLaunchApp app) {
    final rank = _orderRank(app);
    if (rank == 1) return 'Recommended';
    if (rank <= 4) return 'Try this app';
    return 'May vary by bank support';
  }
}