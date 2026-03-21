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

  Future<void> checkAndTriggerNotifications({
    required List<Expense> expenses,
    required int dailyLimit,
    required int monthlyBudget,
    required int rent,
    required GamificationStats gamificationStats,
    required List<Challenge> challenges,
    required DateTime cycleStart,
    required DateTime cycleEnd,
  }) async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final todaySpent = expenses
        .where((e) => !e.date.isBefore(todayStart) && e.date.isBefore(todayEnd))
        .fold(0, (sum, e) => sum + e.amount);

    final availableBudget = monthlyBudget - rent;

    await _checkOverspendAlert(todaySpent, dailyLimit);

    await _checkStreakNotifications(
      gamificationStats.currentStreak,
      gamificationStats.totalPoints,
      challenges,
    );

    await _checkRewardNotifications(
      challenges,
      gamificationStats,
    );

    await _checkBadgeNotifications(gamificationStats);

    await _checkReminderNotifications(
      expenses: expenses,
      todayStart: todayStart,
      dailyLimit: dailyLimit,
      availableBudget: availableBudget,
      challenges: challenges,
    );
  }

  Future<void> _checkOverspendAlert(int todaySpent, int dailyLimit) async {
    if (todaySpent > dailyLimit && dailyLimit > 0) {
      await NotificationService.instance.showOverspendAlert(
        todaySpent,
        dailyLimit,
      );
    }
  }

  Future<void> _checkStreakNotifications(
    int currentStreak,
    int totalPoints, [
    List<Challenge>? challenges,
  ]) async {
    if (_previousStreak != null && currentStreak > _previousStreak!) {
      await NotificationService.instance.showStreakUpdate(
        currentStreak,
        20,
      );
    }

    if (_previousStreak != null &&
        _previousStreak! > 0 &&
        currentStreak == 0 &&
        _previousStreakBroken != true) {
      _previousStreakBroken = true;
      await NotificationService.instance.showStreakBroken();
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

  Future<void> _checkBadgeNotifications(GamificationStats stats) async {
    if (stats.badgesUnlocked.isNotEmpty) {
      final latestBadge = stats.badgesUnlocked.last;
      await NotificationService.instance.showBadgeUnlocked(latestBadge);
    }
  }

  Future<void> _checkReminderNotifications({
    required List<Expense> expenses,
    required DateTime todayStart,
    required int dailyLimit,
    required int availableBudget,
    required List<Challenge> challenges,
  }) async {
    final todayExpenses = expenses
        .where((e) =>
            !e.date.isBefore(todayStart) &&
            e.date.isBefore(todayStart.add(const Duration(days: 1))))
        .toList();

    if (todayExpenses.isEmpty) {
      final now = DateTime.now();
      if (now.hour >= 18) {
        await NotificationService.instance.showExpenseReminder();
      }
    }

    final activeChallenges = challenges.where((c) => !c.isCompleted).toList();
    if (activeChallenges.isNotEmpty) {
      final hasDailyChallenge = activeChallenges.any(
        (c) => c.challengeType == ChallengeType.daily,
      );
      if (hasDailyChallenge) {
        final activeDaily = activeChallenges.firstWhere(
          (c) => c.challengeType == ChallengeType.daily,
          orElse: () => activeChallenges.first,
        );
        await NotificationService.instance.showChallengeReminder(
          activeDaily.title,
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
    await NotificationService.instance.showExpenseReminder();
  }

  Future<void> triggerChallengeReminder(String challengeTitle) async {
    await NotificationService.instance.showChallengeReminder(challengeTitle);
  }
}
