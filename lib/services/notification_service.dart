import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  final Random _random = Random();

  static const List<String> _dailySuggestions = <String>[
    'Set a daily spending cap and check it before every payment.',
    'Move even ₹10 into savings before starting your day.',
    'Avoid one impulse purchase today and track the difference.',
    'Review yesterday\'s top expense and cut it by 10% today.',
    'Use Scan-to-Pay mindfully and categorize every transaction correctly.',
  ];

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'budget_tracker_channel',
    'Budget Alerts',
    channelDescription: 'Budget reminders and sync alerts',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: android);
      await _notifications.initialize(settings);
      _initialized = true;
    } catch (_) {
      // Initialization failed — notifications will be silently disabled.
    }
  }

  Future<void> requestPermissionAndSchedule() async {
    if (!_initialized) {
      return;
    }

    bool granted = false;
    try {
      granted = await _notifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    } catch (_) {
      return;
    }

    if (granted) {
      await showWelcomeNotification();
      await showDailyMorningSuggestionIfNeeded();
    }
  }

  /// Shows a one-time notification after the user grants permission.
  /// Does NOT use periodicallyShow — avoids SCHEDULE_EXACT_ALARM requirement.
  Future<void> showWelcomeNotification() async {
    if (!_initialized) {
      return;
    }

    try {
      await _notifications.show(
        1001,
        'Budget Tracker is ready 🎉',
        "You're all set! Track daily spending and stay within your budget.",
        const NotificationDetails(android: _androidDetails),
      );
    } catch (_) {
      // Non-critical — silently ignored.
    }
  }

  Future<void> showSyncRestoredNotification() async {
    if (!_initialized) {
      return;
    }

    try {
      await _notifications.show(
        1002,
        'Back online',
        'Auto-sync resumed and latest expenses are being updated.',
        const NotificationDetails(android: _androidDetails),
      );
    } catch (_) {
      // Ignore — non-critical notification.
    }
  }

  Future<void> showDailyMorningSuggestionIfNeeded() async {
    if (!_initialized) {
      return;
    }

    final now = DateTime.now();
    if (now.hour < 6 || now.hour > 11) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final todayKey = '${now.year}-${now.month}-${now.day}';
    final lastShownKey = prefs.getString('daily_suggestion_last_date');
    if (lastShownKey == todayKey) {
      return;
    }

    final suggestion = _dailySuggestions[_random.nextInt(_dailySuggestions.length)];

    try {
      await _notifications.show(
        1003,
        'Morning Budget Tip ☀️',
        suggestion,
        const NotificationDetails(android: _androidDetails),
      );
      await prefs.setString('daily_suggestion_last_date', todayKey);
    } catch (_) {
      // Ignore non-critical notification failures.
    }
  }
}
