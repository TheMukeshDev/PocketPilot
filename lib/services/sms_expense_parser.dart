/// Parses bank/UPI SMS messages and extracts expense data.
///
/// Detects debit transactions, extracts the amount and merchant,
/// and maps well-known merchants to expense categories.
class SmsExpenseParser {
  // ── Debit keywords ───────────────────────────────────────────────────────
  static const List<String> _debitKeywords = [
    'debited',
    'debit',
    'spent',
    'paid',
    'deducted',
    'payment of',
    'purchase of',
    'withdrawn',
    'txn of',
    'transaction of',
    'debited for',
    'upi txn',
  ];

  // ── Merchant → Category mapping ──────────────────────────────────────────
  static const Map<String, String> merchantCategories = {
    // Food
    'swiggy': 'Food',
    'zomato': 'Food',
    'dominos': 'Food',
    'mcdonald': 'Food',
    'kfc': 'Food',
    'burger king': 'Food',
    'subway': 'Food',
    'dunzo': 'Food',
    'bigbasket': 'Food',
    'blinkit': 'Food',
    'zepto': 'Food',
    'instamart': 'Food',
    'uber eats': 'Food',
    // Travel
    'uber': 'Travel',
    'ola': 'Travel',
    'rapido': 'Travel',
    'irctc': 'Travel',
    'makemytrip': 'Travel',
    'goibibo': 'Travel',
    'cleartrip': 'Travel',
    'redbus': 'Travel',
    'metro': 'Travel',
    'petrol': 'Travel',
    'fuel': 'Travel',
    // Shopping
    'amazon': 'Shopping',
    'flipkart': 'Shopping',
    'myntra': 'Shopping',
    'ajio': 'Shopping',
    'meesho': 'Shopping',
    'snapdeal': 'Shopping',
    'nykaa': 'Shopping',
    // Health
    'netmeds': 'Health',
    'pharmeasy': 'Health',
    'apollo': 'Health',
    'medlife': 'Health',
    'hospital': 'Health',
    'clinic': 'Health',
    'pharmacy': 'Health',
    // Entertainment
    'netflix': 'Entertainment',
    'hotstar': 'Entertainment',
    'prime video': 'Entertainment',
    'spotify': 'Entertainment',
    'disney': 'Entertainment',
    'bookmyshow': 'Entertainment',
    'pvr': 'Entertainment',
    'inox': 'Entertainment',
    // Bills
    'jio': 'Bills',
    'airtel': 'Bills',
    'bsnl': 'Bills',
    'electricity': 'Bills',
    'broadband': 'Bills',
    'recharge': 'Bills',
    // Study
    'udemy': 'Study',
    'coursera': 'Study',
    'byju': 'Study',
  };

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns [SmsExpenseData] when [sms] contains a debit transaction,
  /// or `null` when it is not a transaction message.
  static SmsExpenseData? parse(String sms) {
    final lower = sms.toLowerCase();

    // 1. Must contain a debit keyword.
    if (!_debitKeywords.any((kw) => lower.contains(kw))) return null;

    // 2. Skip credit / refund messages.
    if (lower.contains('credited') ||
        lower.contains('received') ||
        lower.contains('refund')) {
      return null;
    }

    // 3. Extract amount (required).
    final amount = _extractAmount(sms);
    if (amount == null || amount <= 0) return null;

    // 4. Derive merchant and category.
    final merchant = _extractMerchant(sms);
    final category = _detectCategory(merchant);

    return SmsExpenseData(
      title: _formatTitle(merchant),
      amount: amount,
      category: category,
      rawSms: sms,
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static int? _extractAmount(String sms) {
    // Supports: Rs. 250, Rs:250, Rs250, INR 250, ₹250, ₹ 1,250.50, 1250.75
    final pattern = RegExp(
      r'(?:Rs\.?\s*:?\s*|INR\s*:?\s*|₹\s*)(\d[\d,]*(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(sms);
    if (match == null) return null;
    final raw = match.group(1)!.replaceAll(',', '');
    final parsed = double.tryParse(raw);
    return parsed?.round();
  }

  static String _extractMerchant(String sms) {
    // Pattern 1: "to <Merchant>" — common in UPI transaction SMS
    final toPattern = RegExp(
      r'\bto\s+([A-Za-z0-9][A-Za-z0-9\s&\-\.]{0,40}?)(?:\s+(?:via|on|ref|upi|vpa|for|at|using|a\/c)|[.,;\n]|$)',
      caseSensitive: false,
    );
    final toMatch = toPattern.firstMatch(sms);
    if (toMatch != null) {
      final candidate = toMatch.group(1)?.trim() ?? '';
      // Reject if it looks like an account number (all digits/XXXX pattern)
      if (candidate.isNotEmpty &&
          candidate.split(' ').length <= 4 &&
          !RegExp(r'^[\dXx]+$').hasMatch(candidate)) {
        return candidate;
      }
    }

    // Pattern 2: "at <Merchant>" — card swipe at POS
    final atPattern = RegExp(
      r'\bat\s+([A-Za-z0-9][A-Za-z0-9\s&\-\.]{0,40}?)(?:\s+(?:via|on|ref|upi|vpa|for|using)|[.,;\n]|$)',
      caseSensitive: false,
    );
    final atMatch = atPattern.firstMatch(sms);
    if (atMatch != null) {
      final candidate = atMatch.group(1)?.trim() ?? '';
      if (candidate.isNotEmpty && candidate.split(' ').length <= 4) {
        return candidate;
      }
    }

    // Fallback: check known merchant keywords in the message.
    final lower = sms.toLowerCase();
    for (final kw in merchantCategories.keys) {
      if (lower.contains(kw)) return kw;
    }

    return 'Unknown';
  }

  static String _detectCategory(String merchant) {
    final lower = merchant.toLowerCase();
    for (final entry in merchantCategories.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return 'Other';
  }

  static String _formatTitle(String merchant) {
    if (merchant.isEmpty || merchant == 'Unknown') return 'Auto Detected';
    return merchant
        .split(' ')
        .map((word) => word.isEmpty
            ? ''
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ')
        .trim();
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class SmsExpenseData {
  final String title;
  final int amount;
  final String category;
  final String rawSms;

  const SmsExpenseData({
    required this.title,
    required this.amount,
    required this.category,
    required this.rawSms,
  });
}
