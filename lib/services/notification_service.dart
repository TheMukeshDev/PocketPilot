import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../models/app_notification.dart';
import 'notification_preferences_service.dart';

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

  static const List<String> _reminderMessages = <String>[
    'Log today\'s expenses to keep your budget accurate.',
    'Your savings challenge is waiting. Check your progress!',
    'Don\'t forget to track today\'s spending.',
    'A quick expense log keeps your budget on track.',
    'Stay ahead of your budget - log expenses now.',
  ];

  static const AndroidNotificationDetails _budgetChannelDetails =
      AndroidNotificationDetails(
    'budget_tracker_channel',
    'Budget Alerts',
    channelDescription: 'Budget reminders and spending alerts',
    importance: Importance.high,
    priority: Priority.high,
    styleInformation: BigTextStyleInformation(''),
  );

  static const AndroidNotificationDetails _engagementChannelDetails =
      AndroidNotificationDetails(
    'budget_tracker_engagement',
    'Reminders & Tips',
    channelDescription: 'Budget tips and engagement reminders',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static const AndroidNotificationDetails _rewardsChannelDetails =
      AndroidNotificationDetails(
    'budget_tracker_rewards',
    'Rewards & Achievements',
    channelDescription: 'Points, badges, and streak notifications',
    importance: Importance.high,
    priority: Priority.high,
  );

  int _notificationIdCounter = 0;
  int get _nextNotificationId => ++_notificationIdCounter;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: android);
      await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      _initialized = true;
    } catch (_) {
      // Initialization failed — notifications will be silently disabled.
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - can navigate to specific screen
  }

  Future<bool> requestPermissionAndSchedule() async {
    if (!_initialized) {
      return false;
    }

    bool granted = false;
    try {
      granted = await _notifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    } catch (_) {
      return false;
    }

    if (granted) {
      await showWelcomeNotification();
      await scheduleEngagementReminders();
    }

    return granted;
  }

  Future<void> showWelcomeNotification() async {
    if (!_initialized) {
      return;
    }

    try {
      await _notifications.show(
        1001,
        'PocketPilot is ready!',
        "Track daily spending and stay within your budget.",
        const NotificationDetails(android: _budgetChannelDetails),
      );
    } catch (_) {
      // Non-critical — silently ignored.
    }
  }

  Future<void> showSyncRestoredNotification() async {
    if (!_initialized) {
      return;
    }

    final prefs = await NotificationPreferencesService.instance.loadPreferences();
    if (!prefs.masterEnabled || !prefs.reminderNotificationsEnabled) {
      return;
    }

    try {
      await _notifications.show(
        1002,
        'Back online',
        'Auto-sync resumed and latest expenses are being updated.',
        const NotificationDetails(android: _engagementChannelDetails),
      );
    } catch (_) {
      // Ignore — non-critical notification.
    }
  }

  Future<void> showDailyMorningSuggestionIfNeeded() async {
    if (!_initialized) {
      return;
    }

    final prefs = await NotificationPreferencesService.instance.loadPreferences();
    if (!prefs.masterEnabled || !prefs.reminderNotificationsEnabled) {
      return;
    }

    final now = DateTime.now();
    if (now.hour < 6 || now.hour > 11) {
      return;
    }

    final todayKey = '${now.year}-${now.month}-${now.day}';
    try {
      final storedPrefs = await SharedPreferences.getInstance();
      final lastShownKey = storedPrefs.getString('daily_suggestion_last_date');
      if (lastShownKey == todayKey) {
        return;
      }

      final suggestion =
          _dailySuggestions[_random.nextInt(_dailySuggestions.length)];

      await _notifications.show(
        1003,
        'Morning Budget Tip',
        suggestion,
        const NotificationDetails(android: _engagementChannelDetails),
      );
      await storedPrefs.setString('daily_suggestion_last_date', todayKey);
    } catch (_) {
      // Ignore non-critical notification failures.
    }
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_initialized) {
      return;
    }

    final prefs = await NotificationPreferencesService.instance.loadPreferences();
    if (!prefs.masterEnabled) {
      return;
    }

    NotificationCategory category;
    switch (type) {
      case NotificationType.budget:
        category = NotificationCategory.budgetAlerts;
        break;
      case NotificationType.streak:
        category = NotificationCategory.streakUpdates;
        break;
      case NotificationType.reward:
        category = NotificationCategory.rewardsPoints;
        break;
      case NotificationType.reminder:
        category = NotificationCategory.reminderNotifications;
        break;
    }

    if (!prefs.isCategoryEnabled(category)) {
      return;
    }

    final notification = AppNotification(
      id: AppNotification.generateId(),
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now(),
      metadata: metadata,
    );

    await NotificationPreferencesService.instance.addNotification(notification);

    try {
      AndroidNotificationDetails details;
      switch (type) {
        case NotificationType.budget:
          details = _budgetChannelDetails;
          break;
        case NotificationType.streak:
        case NotificationType.reward:
          details = _rewardsChannelDetails;
          break;
        case NotificationType.reminder:
          details = _engagementChannelDetails;
          break;
      }

      await _notifications.show(
        _nextNotificationId,
        title,
        body,
        NotificationDetails(android: details),
      );
    } catch (_) {
      // Silently ignore
    }
  }

  Future<void> showOverspendAlert(int todaySpent, int dailyLimit) async {
    final today = DateTime.now();
    final tracker = await NotificationPreferencesService.instance
        .loadDailyTracker(today);

    if (tracker.overspendAlertSent) {
      return;
    }

    final updatedTracker = tracker.copyWith(overspendAlertSent: true);
    await NotificationPreferencesService.instance.saveDailyTracker(updatedTracker);

    await showInstantNotification(
      title: 'Budget Alert',
      body: 'You have crossed today\'s spending limit of ₹$dailyLimit. '
          'Try to reduce spending for the rest of the day.',
      type: NotificationType.budget,
      metadata: {
        'todaySpent': todaySpent,
        'dailyLimit': dailyLimit,
        'event': 'overspend',
      },
    );
  }

  Future<void> showStreakUpdate(int currentStreak, int pointsEarned) async {
    final today = DateTime.now();
    final tracker = await NotificationPreferencesService.instance
        .loadDailyTracker(today);

    if (tracker.streakAlertSent) {
      return;
    }

    final updatedTracker = tracker.copyWith(streakAlertSent: true);
    await NotificationPreferencesService.instance.saveDailyTracker(updatedTracker);

    String body;
    if (currentStreak == 3 ||
        currentStreak == 7 ||
        currentStreak == 15 ||
        currentStreak == 30) {
      body = 'Amazing! You\'ve reached a $currentStreak-day streak! '
          'You earned +$pointsEarned points.';
    } else {
      body = 'Great job! Your saving streak is now $currentStreak days. '
          'You earned +$pointsEarned points.';
    }

    await showInstantNotification(
      title: 'Streak Updated',
      body: body,
      type: NotificationType.streak,
      metadata: {
        'currentStreak': currentStreak,
        'pointsEarned': pointsEarned,
        'event': 'streak_update',
      },
    );
  }

  Future<void> showStreakBroken() async {
    final today = DateTime.now();
    final tracker = await NotificationPreferencesService.instance
        .loadDailyTracker(today);

    if (tracker.streakBrokenAlertSent) {
      return;
    }

    final updatedTracker = tracker.copyWith(streakBrokenAlertSent: true);
    await NotificationPreferencesService.instance.saveDailyTracker(updatedTracker);

    await showInstantNotification(
      title: 'Streak Broken',
      body: 'Your saving streak reset today. Start again and keep going!',
      type: NotificationType.streak,
      metadata: {
        'event': 'streak_broken',
      },
    );
  }

  Future<void> showPointsEarned(int points, String challengeTitle) async {
    final today = DateTime.now();
    final tracker = await NotificationPreferencesService.instance
        .loadDailyTracker(today);

    if (tracker.rewardAlertSent) {
      return;
    }

    final updatedTracker = tracker.copyWith(rewardAlertSent: true);
    await NotificationPreferencesService.instance.saveDailyTracker(updatedTracker);

    await showInstantNotification(
      title: 'Points Earned',
      body: 'You earned +$points points for completing "$challengeTitle"!',
      type: NotificationType.reward,
      metadata: {
        'points': points,
        'challengeTitle': challengeTitle,
        'event': 'points_earned',
      },
    );
  }

  Future<void> showChallengeCompleted(String challengeTitle, int rewardPoints) async {
    await showInstantNotification(
      title: 'Challenge Completed!',
      body: 'Awesome! You completed "$challengeTitle" and earned $rewardPoints points!',
      type: NotificationType.reward,
      metadata: {
        'challengeTitle': challengeTitle,
        'rewardPoints': rewardPoints,
        'event': 'challenge_completed',
      },
    );
  }

  Future<void> showBadgeUnlocked(String badgeName) async {
    await showInstantNotification(
      title: 'Badge Unlocked!',
      body: 'Congratulations! You earned the "$badgeName" badge!',
      type: NotificationType.reward,
      metadata: {
        'badgeName': badgeName,
        'event': 'badge_unlocked',
      },
    );
  }

  Future<void> showReminder({
    required String title,
    required String body,
  }) async {
    final today = DateTime.now();
    final tracker = await NotificationPreferencesService.instance
        .loadDailyTracker(today);

    if (tracker.reminderSent) {
      return;
    }

    final updatedTracker = tracker.copyWith(reminderSent: true);
    await NotificationPreferencesService.instance.saveDailyTracker(updatedTracker);

    await showInstantNotification(
      title: title,
      body: body,
      type: NotificationType.reminder,
    );
  }

  Future<void> showExpenseReminder() async {
    final message =
        _reminderMessages[_random.nextInt(_reminderMessages.length)];
    await showReminder(
      title: 'Log Today\'s Spending',
      body: message,
    );
  }

  Future<void> showChallengeReminder(String challengeTitle) async {
    await showReminder(
      title: 'Stay on Track',
      body: 'Your "$challengeTitle" challenge is waiting. Check your progress!',
    );
  }

  Future<void> scheduleEngagementReminders() async {
    if (!_initialized) {
      return;
    }

    final prefs = await NotificationPreferencesService.instance.loadPreferences();
    if (!prefs.masterEnabled || !prefs.reminderNotificationsEnabled) {
      return;
    }

    try {
      tz_data.initializeTimeZones();
      final scheduledDate = _nextInstanceOf7PM();

      await _notifications.zonedSchedule(
        2001,
        'Log Today\'s Spending',
        'Keep your budget accurate by logging today\'s expenses.',
        scheduledDate,
        const NotificationDetails(android: _engagementChannelDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Scheduling may fail on some devices
    }
  }

  tz.TZDateTime _nextInstanceOf7PM() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      19,
      0,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
