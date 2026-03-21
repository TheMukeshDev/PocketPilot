import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';

class NotificationPreferencesService {
  NotificationPreferencesService._();

  static final NotificationPreferencesService instance =
      NotificationPreferencesService._();

  static const String _prefsKey = 'notification_preferences';
  static const String _historyKey = 'notification_history';
  static const String _dailyTrackerKeyPrefix = 'notification_daily_';

  NotificationPreferences? _cachedPreferences;

  Future<NotificationPreferences> loadPreferences() async {
    if (_cachedPreferences != null) {
      return _cachedPreferences!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && saved.isNotEmpty) {
        _cachedPreferences =
            NotificationPreferences.fromJson(saved);
        return _cachedPreferences!;
      }
    } catch (_) {
      // Return defaults on error
    }

    _cachedPreferences = const NotificationPreferences();
    return _cachedPreferences!;
  }

  Future<void> savePreferences(NotificationPreferences preferences) async {
    _cachedPreferences = preferences;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, preferences.toJson());
    } catch (_) {
      // Silently fail
    }
  }

  Future<void> setMasterEnabled(bool enabled) async {
    final current = await loadPreferences();
    await savePreferences(current.copyWith(masterEnabled: enabled));
  }

  Future<void> setCategoryEnabled(
      NotificationCategory category, bool enabled) async {
    final current = await loadPreferences();
    NotificationPreferences updated;

    switch (category) {
      case NotificationCategory.budgetAlerts:
        updated = current.copyWith(budgetAlertsEnabled: enabled);
        break;
      case NotificationCategory.streakUpdates:
        updated = current.copyWith(streakUpdatesEnabled: enabled);
        break;
      case NotificationCategory.rewardsPoints:
        updated = current.copyWith(rewardsPointsEnabled: enabled);
        break;
      case NotificationCategory.reminderNotifications:
        updated = current.copyWith(reminderNotificationsEnabled: enabled);
        break;
    }

    await savePreferences(updated);
  }

  Future<bool> isCategoryEnabled(NotificationCategory category) async {
    final prefs = await loadPreferences();
    return prefs.isCategoryEnabled(category);
  }

  Future<bool> isMasterEnabled() async {
    final prefs = await loadPreferences();
    return prefs.masterEnabled;
  }

  Future<void> clearCache() async {
    _cachedPreferences = null;
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<NotificationDailyTracker> loadDailyTracker(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_dailyTrackerKeyPrefix${_dateKey(date)}';
      final saved = prefs.getString(key);
      if (saved != null && saved.isNotEmpty) {
        return NotificationDailyTracker.fromMap(
            jsonDecode(saved) as Map<String, dynamic>);
      }
    } catch (_) {
      // Return fresh tracker on error
    }

    return NotificationDailyTracker(date: _dateKey(date));
  }

  Future<void> saveDailyTracker(NotificationDailyTracker tracker) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_dailyTrackerKeyPrefix${tracker.date}';
      await prefs.setString(key, jsonEncode(tracker.toMap()));
    } catch (_) {
      // Silently fail
    }
  }

  Future<List<AppNotification>> loadNotificationHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_historyKey);
      if (saved != null && saved.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(saved) as List<dynamic>;
        return jsonList
            .map((e) => AppNotification.fromMap(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (_) {
      // Return empty list on error
    }

    return [];
  }

  Future<void> saveNotificationHistory(List<AppNotification> notifications) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = notifications.map((e) => e.toMap()).toList();
      await prefs.setString(_historyKey, jsonEncode(jsonList));
    } catch (_) {
      // Silently fail
    }
  }

  Future<void> addNotification(AppNotification notification) async {
    final history = await loadNotificationHistory();
    history.insert(0, notification);

    // Keep only last 50 notifications
    if (history.length > 50) {
      history.removeRange(50, history.length);
    }

    await saveNotificationHistory(history);
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    final history = await loadNotificationHistory();
    final index = history.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      history[index] = history[index].copyWith(isRead: true);
      await saveNotificationHistory(history);
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    final history = await loadNotificationHistory();
    final updated = history.map((n) => n.copyWith(isRead: true)).toList();
    await saveNotificationHistory(updated);
  }

  Future<void> clearNotificationHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (_) {
      // Silently fail
    }
  }

  Future<int> getUnreadCount() async {
    final history = await loadNotificationHistory();
    return history.where((n) => !n.isRead).length;
  }
}
