import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptOcrResult {
  const ReceiptOcrResult({
    required this.rawText,
    this.amount,
    this.merchantName,
  });

  final String rawText;
  final int? amount;
  final String? merchantName;

  bool get hasUsefulData => amount != null || (merchantName?.isNotEmpty ?? false);
}

class ReceiptOcrHelper {
  static Future<ReceiptOcrResult> scanFromPath(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(inputImage);
      final rawText = result.text;

      return ReceiptOcrResult(
        rawText: rawText,
        amount: _extractAmount(rawText),
        merchantName: _extractMerchantName(rawText),
      );
    } finally {
      await recognizer.close();
    }
  }

  static int? _extractAmount(String text) {
    if (text.trim().isEmpty) {
      return null;
    }

    final currencyMatches = RegExp(
      r'(?:₹|rs\.?|inr)\s*(\d[\d,]*(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).allMatches(text);

    double? best;
    for (final match in currencyMatches) {
      final value = double.tryParse((match.group(1) ?? '').replaceAll(',', ''));
      if (value != null && value > 0) {
        best = best == null ? value : (value > best ? value : best);
      }
    }

    if (best != null) {
      return best.round();
    }

    final lines = text.split('\n');
    final amountLineRegex = RegExp(
      r'(total|amount|paid|payment|grand\s+total|net\s+amount|bill\s+amount)',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (!amountLineRegex.hasMatch(line)) {
        continue;
      }
      final numberMatches = RegExp(r'(\d[\d,]*(?:\.\d{1,2})?)').allMatches(line);
      for (final match in numberMatches) {
        final value = double.tryParse((match.group(1) ?? '').replaceAll(',', ''));
        if (value != null && value > 0) {
          best = best == null ? value : (value > best ? value : best);
        }
      }
    }

    return best?.round();
  }

  static String? _extractMerchantName(String text) {
    if (text.trim().isEmpty) {
      return null;
    }

    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    for (final line in lines) {
      if (line.length < 3) {
        continue;
      }
      if (RegExp(r'^[\d\s.,\-/:+()]+$').hasMatch(line)) {
        continue;
      }
      if (RegExp(r'(invoice|receipt|tax\s+invoice|bill\s+no|gstin|phone|mobile|date)', caseSensitive: false).hasMatch(line)) {
        continue;
      }
      if (line.contains('@')) {
        continue;
      }

      final words = line.split(RegExp(r'\s+'));
      final shortName = words.take(4).join(' ');
      return _toTitleCase(shortName);
    }

    return null;
  }

  static String _toTitleCase(String input) {
    return input
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
}
