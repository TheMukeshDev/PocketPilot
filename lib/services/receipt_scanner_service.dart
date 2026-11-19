import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Result of a receipt/screenshot scan.
class ScannedReceiptData {
  final String? title;
  final int? amount;
  final String category;
  final DateTime? date;
  final String rawText;
  final bool usedAi;

  const ScannedReceiptData({
    this.title,
    this.amount,
    required this.category,
    this.date,
    required this.rawText,
    this.usedAi = false,
  });

  bool get hasAmount => amount != null && amount! > 0;
  bool get hasTitle => title != null && title!.isNotEmpty;
  bool get hasDate => date != null;
}

class ReceiptScannerService {
  // Ordered list of all spending categories used throughout the app.
  static const List<String> allCategories = [
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

  static const Map<String, String> categoryEmoji = {
    'Food': '🍛',
    'Travel': '🚗',
    'Shopping': '🛍️',
    'Recharge': '📱',
    'Medical': '💊',
    'Utilities': '⚡',
    'Entertainment': '🎬',
    'Study': '📚',
    'Personal': '✂️',
    'Other': '💰',
  };

  // Keywords per category (case-insensitive match against full OCR text).
  static const Map<String, List<String>> _categoryKeywords = {
    'Food': [
      'zomato',
      'swiggy',
      'restaurant',
      'cafe',
      'dhaba',
      'pizza',
      'burger',
      'food',
      'meal',
      'lunch',
      'dinner',
      'breakfast',
      'biryani',
      'chai',
      'tea',
      'coffee',
      'bakery',
      'canteen',
      'juice',
      'kitchen',
      'snack',
      'sweet',
      'dominos',
      'mcdonald',
      'kfc',
      'subway',
      'haldiram',
    ],
    'Travel': [
      'uber',
      'ola',
      'rapido',
      'metro',
      'bmtc',
      'dtc',
      'bus',
      'train',
      'auto',
      'petrol',
      'fuel',
      'diesel',
      'parking',
      'toll',
      'flight',
      'ticket',
      'cab',
      'taxi',
      'irctc',
      'makemytrip',
      'yatra',
      'redbus',
    ],
    'Shopping': [
      'amazon',
      'flipkart',
      'myntra',
      'meesho',
      'shop',
      'store',
      'mart',
      'mall',
      'bigbasket',
      'blinkit',
      'zepto',
      'instamart',
      'dmart',
      'reliance smart',
      'supermarket',
      'grocery',
    ],
    'Recharge': [
      'airtel',
      'jio',
      'vi ',
      'vodafone',
      'bsnl',
      'recharge',
      'prepaid',
      'postpaid',
      'dth',
      'tata sky',
      'dish tv',
      'broadband',
    ],
    'Medical': [
      'pharmacy',
      'medical',
      'hospital',
      'doctor',
      'clinic',
      'medicine',
      'health',
      'diagnostic',
      'lab',
      'apollo',
      'netmeds',
      '1mg',
      'pharmeasy',
      'chemist',
      'dispensary',
    ],
    'Utilities': [
      'electricity',
      'water bill',
      'gas bill',
      'maintenance',
      'society fee',
      'bescom',
      'bses',
      'tpddl',
      'igl',
      'mahanagar gas',
      'electric bill',
    ],
    'Entertainment': [
      'netflix',
      'spotify',
      'hotstar',
      'prime video',
      'youtube premium',
      'cinema',
      'movie',
      'theatre',
      'pvr',
      'inox',
      'bookmyshow',
      'gaming',
    ],
    'Study': [
      'book',
      'course fee',
      'udemy',
      'fees',
      'tuition',
      'college fee',
      'school fee',
      'exam',
      'stationery',
      'coursera',
      'byju',
      'unacademy',
    ],
    'Personal': [
      'salon',
      'spa',
      'haircut',
      'gym',
      'fitness',
      'barber',
      'beauty',
      'parlour',
    ],
  };

  // ─── Public entry point ───────────────────────────────────────────────────

  /// Scans [imagePath] with on-device OCR.
  static Future<ScannedReceiptData> scanFromPath(String imagePath) async {
    final rawText = await _runOcr(imagePath);

    final amount = _extractAmount(rawText);
    final title = _extractTitle(rawText);
    final date = _extractDate(rawText);
    final category = _detectCategory(rawText);

    return ScannedReceiptData(
      title: title,
      amount: amount,
      category: category,
      date: date,
      rawText: rawText,
    );
  }

  // ─── OCR ─────────────────────────────────────────────────────────────────

  static Future<String> _runOcr(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result =
          await recognizer.processImage(InputImage.fromFilePath(imagePath));
      return result.text;
    } finally {
      await recognizer.close();
    }
  }

  // ─── Amount extraction ────────────────────────────────────────────────────

  static int? _extractAmount(String text) {
    if (text.trim().isEmpty) return null;

    final paymentAmount = _extractPaymentAmount(text);
    if (paymentAmount != null) {
      return paymentAmount;
    }

    final lines = text.split('\n');

    // Keywords that indicate an amount-containing line.
    final amountLineRe = RegExp(
      r'\b(total|amount|paid|payment|debit|credit|net amount|grand total|'
      r'balance|charge|fare|bill amount|you paid|you sent|txn amount)\b',
      caseSensitive: false,
    );

    // General number pattern (handles "1,500.50" and "1500").
    final numRe = RegExp(r'(\d[\d,]*(?:\.\d{1,2})?)', caseSensitive: false);

    double? best;

    // Pass 1 — lines containing payment-related keywords.
    for (final line in lines) {
      if (amountLineRe.hasMatch(line)) {
        for (final m in numRe.allMatches(line)) {
          final val = double.tryParse(m.group(1)!.replaceAll(',', ''));
          if (val != null && val >= 1 && val <= 999999) {
            if (best == null || val > best) best = val;
          }
        }
      }
    }

    // Pass 2 — any currency-prefixed value in full text.
    final currencyRe = RegExp(
      r'(?:₹|rs\.?|inr)\s*(\d[\d,]*(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    for (final m in currencyRe.allMatches(text)) {
      final val = double.tryParse(m.group(1)!.replaceAll(',', ''));
      if (val != null && val >= 1 && val <= 999999) {
        if (best == null || val > best) best = val;
      }
    }

    if (best != null) return best.round();

    // Pass 3 — largest standalone number in full text (last resort).
    double? max;
    for (final m in RegExp(r'\b(\d[\d,]*(?:\.\d{1,2})?)\b').allMatches(text)) {
      final val = double.tryParse(m.group(1)!.replaceAll(',', ''));
      if (val != null && val >= 1 && val <= 999999) {
        if (max == null || val > max) max = val;
      }
    }
    return max?.round();
  }

  static int? _extractPaymentAmount(String text) {
    final normalized = text.replaceAll('\r', '');

    final currencyMatch = RegExp(
      r'(?:payment\s+to|paid|sent|debited|amount|total|fare|charge)[^\n₹]*₹\s?(\d{1,6}(?:,\d{3})*(?:\.\d{1,2})?)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(normalized);
    if (currencyMatch != null) {
      return double.tryParse(currencyMatch.group(1)!.replaceAll(',', ''))
          ?.round();
    }

    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].toLowerCase();
      if (!_looksLikePaymentLine(line)) {
        continue;
      }

      for (var offset = 0;
          offset <= 4 && index + offset < lines.length;
          offset++) {
        final candidate = _parseStandaloneAmount(lines[index + offset]);
        if (candidate != null) {
          return candidate;
        }
      }
    }

    return null;
  }

  static int? _parseStandaloneAmount(String line) {
    final normalized = line.trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.contains(':') ||
        normalized.toLowerCase().contains('kb/s') ||
        normalized.contains('@')) {
      return null;
    }

    final currency = RegExp(r'₹\s?(\d{1,6}(?:,\d{3})*(?:\.\d{1,2})?)')
        .firstMatch(normalized);
    if (currency != null) {
      return double.tryParse(currency.group(1)!.replaceAll(',', ''))?.round();
    }

    if (RegExp(r'^\d{1,6}(?:,\d{3})*(?:\.\d{1,2})?$').hasMatch(normalized)) {
      return double.tryParse(normalized.replaceAll(',', ''))?.round();
    }

    return null;
  }

  static bool _looksLikePaymentLine(String line) {
    return RegExp(
      r'payment\s+to|paid|sent\s+to|transaction\s+successful|debited|phonepe|gpay|google pay|paytm|upi|fare|cab|ride|metro|train|bus|flight|fuel|parking|toll',
      caseSensitive: false,
    ).hasMatch(line);
  }

  // ─── Title / merchant extraction ──────────────────────────────────────────

  static String? _extractTitle(String text) {
    if (text.trim().isEmpty) return null;

    final multilinePayment = RegExp(
      r'payment\s+to\s+([A-Za-z][A-Za-z\s]{2,80})\n([A-Za-z][A-Za-z\s]{2,80})?',
      caseSensitive: false,
    ).firstMatch(text);
    if (multilinePayment != null) {
      final combined = [
        multilinePayment.group(1),
        multilinePayment.group(2),
      ].whereType<String>().join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (combined.isNotEmpty) {
        return _cleanExtractedTitle(combined);
      }
    }

    // UPI payment screenshot patterns.
    final upiPatterns = [
      RegExp(r'paid\s+to\s+([^\n₹\d@]{3,50})', caseSensitive: false),
      RegExp(
        r'(?:sent|transferred)\s+(?:₹[\d,]+\s+)?to\s+([^\n₹\d@]{3,50})',
        caseSensitive: false,
      ),
      RegExp(r'payment\s+to\s+([^\n₹\d@]{3,50})', caseSensitive: false),
      RegExp(r'you\s+paid\s+(?:₹[\d,]+\s+)?to\s+([^\n₹\d@]{3,50})',
          caseSensitive: false),
    ];

    for (final re in upiPatterns) {
      final m = re.firstMatch(text);
      if (m != null) {
        final merchant = m.group(1)?.trim().split('\n').first.trim() ?? '';
        if (merchant.length >= 2) return _cleanExtractedTitle(merchant);
      }
    }

    // Fallback — first meaningful non-numeric, non-ID line.
    final meaningful = text.split('\n').map((l) => l.trim()).where((l) {
      if (l.length < 3) return false;
      if (RegExp(r'^[\d\s.,\-/:+()]+$').hasMatch(l)) return false;
      if (RegExp(r'^\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}').hasMatch(l)) {
        return false;
      }
      if (l.contains('@') && l.length < 40) return false; // UPI VPA
      if (RegExp(
        r'^(txn|ref|utr|order|trans|invoice|gstin|gst)\s*[:\-#]?\s*\d',
        caseSensitive: false,
      ).hasMatch(l)) {
        return false;
      }
      return true;
    });

    return meaningful.isNotEmpty
        ? _cleanExtractedTitle(meaningful.first)
        : null;
  }

  static String _cleanExtractedTitle(String raw) {
    final cleaned = raw
        .replaceAll(
            RegExp(r'\b(transaction successful|learn more|message|paid)\b',
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return _toTitleCase(cleaned);
  }

  static String _toTitleCase(String s) {
    return s.trim().split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  // ─── Date extraction ──────────────────────────────────────────────────────

  static DateTime? _extractDate(String text) {
    const monthMap = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };

    // "15 Jan 2025" or "15-Jan-25"
    var m = RegExp(
      r'(\d{1,2})[\s\-](jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*[\s\-,]+(\d{2,4})',
      caseSensitive: false,
    ).firstMatch(text);
    if (m != null) {
      final d = _tryBuildDate(
        int.tryParse(m.group(3)!),
        monthMap[m.group(2)!.toLowerCase().substring(0, 3)],
        int.tryParse(m.group(1)!),
      );
      if (d != null) return d;
    }

    // "Jan 15, 2025"
    m = RegExp(
      r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*\s+(\d{1,2}),?\s+(\d{2,4})',
      caseSensitive: false,
    ).firstMatch(text);
    if (m != null) {
      final d = _tryBuildDate(
        int.tryParse(m.group(3)!),
        monthMap[m.group(1)!.toLowerCase().substring(0, 3)],
        int.tryParse(m.group(2)!),
      );
      if (d != null) return d;
    }

    // YYYY-MM-DD
    m = RegExp(r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(text);
    if (m != null) {
      final d = _tryBuildDate(
        int.tryParse(m.group(1)!),
        int.tryParse(m.group(2)!),
        int.tryParse(m.group(3)!),
      );
      if (d != null) return d;
    }

    // DD/MM/YYYY or DD-MM-YYYY
    m = RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})').firstMatch(text);
    if (m != null) {
      final d = _tryBuildDate(
        int.tryParse(m.group(3)!),
        int.tryParse(m.group(2)!),
        int.tryParse(m.group(1)!),
      );
      if (d != null &&
          d.isBefore(DateTime.now().add(const Duration(days: 1))) &&
          d.isAfter(DateTime(2010))) {
        return d;
      }
    }

    return null;
  }

  static DateTime? _tryBuildDate(int? year, int? month, int? day) {
    if (year == null || month == null || day == null) return null;
    final y = year < 100 ? 2000 + year : year;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime.tryParse(
      '$y-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
    );
  }

  // ─── Category detection ───────────────────────────────────────────────────

  static String _detectCategory(String text) {
    if (text.trim().isEmpty) return 'Other';
    final lower = text.toLowerCase();

    if (RegExp(
      r'uber|ola|rapido|cab|ride|auto|metro|train|bus|flight|fuel|petrol|diesel|parking|toll|irctc',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return 'Travel';
    }

    final scores = <String, int>{};

    _categoryKeywords.forEach((cat, keywords) {
      var score = 0;
      for (final kw in keywords) {
        if (lower.contains(kw)) score++;
      }
      if (score > 0) scores[cat] = score;
    });

    if (scores.isEmpty) return 'Other';
    return scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
