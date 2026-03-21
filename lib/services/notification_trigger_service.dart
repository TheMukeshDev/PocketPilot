import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/challenge.dart';
import '../models/expense.dart';
import 'notification_service.dart';

class NotificationTriggerService {
  NotificationTriggerService._();

  static final NotificationTriggerService instance =
      NotificationTriggerService._();

  int? _previousStreak;
  bool? _previousStreakBroken;
  final Set<String> _notifiedChallengeIds = {};
  
  static const String _sentNotificationsKey = 'sent_notifications_today';

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<Set<String>> _loadSentNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayKey = _todayKey();
      final stored = prefs.getString('$_sentNotificationsKey$todayKey');
      if (stored != null && stored.isNotEmpty) {
        return Set<String>.from(jsonDecode(stored) as List);
      }
    } catch (_) {}
    return {};
  }

  Future<void> _saveSentNotifications(Set<String> sent) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayKey = _todayKey();
      await prefs.setString('$_sentNotificationsKey$todayKey', jsonEncode(sent.toList()));
    } catch (_) {}
  }

  Future<bool> _canSendNotification(String type) async {
    final sent = await _loadSentNotifications();
    if (sent.contains(type)) {
      return false;
    }
    sent.add(type);
    await _saveSentNotifications(sent);
    return true;
  }

  Future<void> checkAndTriggerNotifications({
    required List<Expense> expenses,
    required int dailyLimit,
    required int monthlyBudget,
    required int rent,
    required GamificationStats gamificationStats,
    required List<Challenge> challenges,
    required DateTime cycleStart,
    required DateTime cycleEnd,
    bool isManualRefresh = false,
  }) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final todaySpent = expenses
        .where((e) => !e.date.isBefore(todayStart) && e.date.isBefore(todayEnd))
        .fold(0, (sum, e) => sum + e.amount);

    // Only send overspend alert after 6 PM or on manual refresh (but only once per day)
    if (now.hour >= 18 || isManualRefresh) {
      if (await _canSendNotification('overspend') && todaySpent > dailyLimit && dailyLimit > 0) {
        await NotificationService.instance.showOverspendAlert(todaySpent, dailyLimit);
      }
    }

    // Only check streak notifications at end of day or manual refresh
    if (now.hour >= 18 || isManualRefresh) {
      await _checkStreakNotifications(
        gamificationStats.currentStreak,
        gamificationStats.totalPoints,
        challenges,
      );
    }

    // Only check reward notifications on manual refresh
    if (isManualRefresh) {
      await _checkRewardNotifications(challenges, gamificationStats);
    }

    // Only check reminders at specific times (evening 6-9 PM)
    if (now.hour >= 18 && now.hour <= 21) {
      if (await _canSendNotification('reminder_expense')) {
        final todayExpenses = expenses
            .where((e) =>
                !e.date.isBefore(todayStart) &&
                e.date.isBefore(todayEnd))
            .toList();
        if (todayExpenses.isEmpty) {
          await NotificationService.instance.showExpenseReminder();
        }
      }
    }
  }

  Future<void> checkOverspendOnExpenseAdded(int todaySpent, int dailyLimit) async {
    if (todaySpent > dailyLimit && dailyLimit > 0) {
      if (await _canSendNotification('overspend')) {
        await NotificationService.instance.showOverspendAlert(todaySpent, dailyLimit);
      }
    }
  }

  Future<void> checkRewardOnChallengeComplete(
    List<Challenge> challenges,
    GamificationStats stats,
  ) async {
    await _checkRewardNotifications(challenges, stats);
  }

  Future<void> _checkStreakNotifications(
    int currentStreak,
    int totalPoints, [
    List<Challenge>? challenges,
  ]) async {
    if (_previousStreak != null && currentStreak > _previousStreak!) {
      if (await _canSendNotification('streak_update')) {
        await NotificationService.instance.showStreakUpdate(currentStreak, 20);
      }
    }

    if (_previousStreak != null &&
        _previousStreak! > 0 &&
        currentStreak == 0 &&
        _previousStreakBroken != true) {
      _previousStreakBroken = true;
      if (await _canSendNotification('streak_broken')) {
        await NotificationService.instance.showStreakBroken();
      }
    }

    _previousStreak = currentStreak;
    if (currentStreak > 0) {
      _previousStreakBroken = false;
    }
  }

  Future<void> _checkRewardNotifications(
    List<Challenge> challenges,
    GamificationStats stats,
  ) async {
    for (final challenge in challenges) {
      if (challenge.isCompleted && !_notifiedChallengeIds.contains(challenge.id)) {
        _notifiedChallengeIds.add(challenge.id);
        await NotificationService.instance.showChallengeCompleted(
          challenge.title,
          challenge.rewardPoints,
        );
        await NotificationService.instance.showPointsEarned(
          challenge.rewardPoints,
          challenge.title,
        );
      }
    }
  }

  void resetChallengeNotifications() {
    _notifiedChallengeIds.clear();
  }

  void updatePreviousStreak(int streak) {
    _previousStreak = streak;
  }

  Future<void> triggerManualReminder() async {
    if (await _canSendNotification('reminder_expense')) {
      await NotificationService.instance.showExpenseReminder();
    }
  }

  Future<void> triggerChallengeReminder(String challengeTitle) async {
    if (await _canSendNotification('reminder_challenge')) {
      await NotificationService.instance.showChallengeReminder(challengeTitle);
    }
  }
}
