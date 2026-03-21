import 'package:shared_preferences/shared_preferences.dart';

enum SmsApprovalMode {
  askEveryTime,
  alwaysApprove,
  alwaysAddDirectly,
}

extension SmsApprovalModeX on SmsApprovalMode {
  String get value {
    switch (this) {
      case SmsApprovalMode.askEveryTime:
        return 'ask_every_time';
      case SmsApprovalMode.alwaysApprove:
        return 'always_approve';
      case SmsApprovalMode.alwaysAddDirectly:
        return 'always_add_directly';
    }
  }

  String get label {
    switch (this) {
      case SmsApprovalMode.askEveryTime:
        return 'Ask Every Time';
      case SmsApprovalMode.alwaysApprove:
        return 'Always Approve';
      case SmsApprovalMode.alwaysAddDirectly:
        return 'Always Add Directly';
    }
  }

  String get description {
    switch (this) {
      case SmsApprovalMode.askEveryTime:
        return 'Show confirmation dialog for each detected transaction SMS.';
      case SmsApprovalMode.alwaysApprove:
        return 'Auto-approve detected SMS and add expense with parsed values.';
      case SmsApprovalMode.alwaysAddDirectly:
        return 'Skip review and add detected SMS expenses directly.';
    }
  }
}

class SmsTrackingPreferences {
  static const String _approvalModePrefix = 'sms_approval_mode';

  static String _approvalModeKey(String userId) =>
      '${_approvalModePrefix}_$userId';

  static SmsApprovalMode fromValue(String? raw) {
    for (final mode in SmsApprovalMode.values) {
      if (mode.value == raw) {
        return mode;
      }
    }
    return SmsApprovalMode.askEveryTime;
  }

  static Future<SmsApprovalMode> loadForUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_approvalModeKey(userId));
    return fromValue(raw);
  }

  static Future<void> saveForUser(String userId, SmsApprovalMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_approvalModeKey(userId), mode.value);
  }
}
