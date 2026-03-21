import 'package:flutter/foundation.dart';

@immutable
class UpiPaymentValidationResult {
  const UpiPaymentValidationResult({
    required this.upiId,
    required this.receiverName,
    required this.amount,
    required this.note,
  });

  final String upiId;
  final String receiverName;
  final double amount;
  final String note;
}

class UpiPaymentValidators {
  UpiPaymentValidators._();

  static final RegExp upiIdPattern = RegExp(
    r'^[a-zA-Z0-9._\-]{2,256}@[a-zA-Z]{2,64}$',
  );

  static String normalizeUpiId(String value) => value.trim().toLowerCase();

  static String normalizeDisplayText(String value, {required String fallback}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return fallback;
    }

    // Keep it simple and UPI-app-friendly; Uri(queryParameters) will percent-encode.
    return trimmed.replaceAll(RegExp(r'\s+'), ' ');
  }

  static String? validateUpiId(String? value) {
    final upiId = normalizeUpiId(value ?? '');
    if (upiId.isEmpty) {
      return 'UPI ID is required';
    }
    if (!upiIdPattern.hasMatch(upiId)) {
      return 'Enter a valid UPI ID (example@upi)';
    }
    return null;
  }

  static String? validateReceiverName(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) {
      return 'Receiver name is required';
    }
    if (name.length < 2) {
      return 'Receiver name is too short';
    }
    return null;
  }

  static String? validateAmount(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return 'Amount is required';
    }
    final parsed = double.tryParse(raw);
    if (parsed == null) {
      return 'Enter a numeric amount';
    }
    if (parsed <= 0) {
      return 'Amount must be greater than 0';
    }
    return null;
  }

  static double parseAmount(String raw) => double.parse(raw.trim());

  static UpiPaymentValidationResult buildValidatedInput({
    required String upiId,
    required String receiverName,
    required String amountText,
    required String note,
  }) {
    return UpiPaymentValidationResult(
      upiId: normalizeUpiId(upiId),
      receiverName:
          normalizeDisplayText(receiverName, fallback: 'UPI Merchant'),
      amount: parseAmount(amountText),
      note: normalizeDisplayText(note, fallback: 'PocketPilot Payment'),
    );
  }
}
