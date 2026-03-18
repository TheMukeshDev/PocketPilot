import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/challenge.dart';
import '../models/expense.dart';

class ChallengeService {
  ChallengeService._();

  static final ChallengeService instance = ChallengeService._();

  static const String _statsKeyPrefix = 'challenge_stats_';
  static const String _completedKeyPrefix = 'challenge_completed_';

  Future<ChallengeEvaluation> evaluateChallenges({
    required List<Expense> expenses,
    required int dailyLimit,
    required int availableBudget,
    required String userId,
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    final previousStats = _loadStats(prefs, userId);
    final completedIds = _loadCompletedChallengeIds(prefs, userId);

    await _resetOldChallengeRecords(
      prefs: prefs,
      userId: userId,
      now: current,
      existingIds: completedIds,
    );

    final dayStart = DateTime(current.year, current.month, current.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final weekStart = dayStart.subtract(Duration(days: current.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final todaySpent = _sumAmount(
      expenses.where((e) => !e.date.isBefore(dayStart) && e.date.isBefore(dayEnd)),
    );
    final weekSpent = _sumAmount(
      expenses.where((e) => !e.date.isBefore(weekStart) && e.date.isBefore(weekEnd)),
    );

    final dailyCap = dailyLimit <= 0 ? 80 : dailyLimit;
    const weeklySaveTarget = 300;
    final weeklyBudgetCap = dailyCap * 7;
    final weeklySaved =
        (weeklyBudgetCap - weekSpent).clamp(0, 1000000).toInt();

    final fiveDayStreak = _currentUnderLimitStreak(
      expenses: expenses,
      now: current,
      dailyLimit: dailyCap,
      maxDaysToCheck: 30,
    );
    final bestStreak = _longestUnderLimitStreak(
      expenses: expenses,
      dailyLimit: dailyCap,
    );
    const streakTarget = 5;

    final dailyChallenge = Challenge(
      id: 'daily_${_dateKey(current)}',
      title: 'Stay under ₹$dailyCap today',
      description:
          'Keep today spending within your current daily budget of ₹$dailyCap.',
      targetAmount: dailyCap,
      rewardPoints: 20,
      progress: (1 - (todaySpent / dailyCap)).clamp(0.0, 1.0),
      isCompleted: todaySpent <= dailyCap,
      challengeType: ChallengeType.daily,
    );

    final weeklyChallenge = Challenge(
      id: 'weekly_${_weekKey(current)}',
      title: 'Save ₹300 this week',
      description: 'Stay under weekly budget and save at least ₹300.',
      targetAmount: weeklySaveTarget,
      rewardPoints: 40,
      progress: (weeklySaved / weeklySaveTarget).clamp(0.0, 1.0),
      isCompleted: weeklySaved >= weeklySaveTarget,
      challengeType: ChallengeType.weekly,
    );

    final streakChallenge = Challenge(
      id: 'streak_${_dateKey(current)}',
      title: 'Stay under limit for 5 days',
      description: 'Maintain spending under daily limit for 5 consecutive days.',
      targetAmount: streakTarget,
      rewardPoints: 60,
      progress: (fiveDayStreak / streakTarget).clamp(0.0, 1.0),
      isCompleted: fiveDayStreak >= streakTarget,
      challengeType: ChallengeType.streak,
    );

    final generated = [dailyChallenge, weeklyChallenge, streakChallenge];

    final completions = <ChallengeCompletion>[];
    final freshCompletedIds = _loadCompletedChallengeIds(prefs, userId);

    for (final challenge in generated) {
      if (!challenge.isCompleted || freshCompletedIds.contains(challenge.id)) {
        continue;
      }

      freshCompletedIds.add(challenge.id);
      completions.add(
        ChallengeCompletion(
          challenge: challenge,
          pointsEarned: challenge.rewardPoints,
          savedAmount: _savedAmountForChallenge(
            challenge: challenge,
            todaySpent: todaySpent,
            weeklySaved: weeklySaved,
            streakDays: fiveDayStreak,
          ),
        ),
      );
    }

    final nextPoints = previousStats.totalPoints +
        completions.fold<int>(0, (sum, item) => sum + item.pointsEarned);

    final nextStats = previousStats.copyWith(
      totalPoints: nextPoints,
      currentStreak: fiveDayStreak,
      bestStreak: bestStreak,
    );

    final badgeResult = _evaluateBadges(nextStats);
    final finalStats = nextStats.copyWith(
      badgesUnlocked: badgeResult.updatedBadges,
    );

    await prefs.setString(
      _statsKey(userId),
      jsonEncode(finalStats.toMap()),
    );
    await prefs.setStringList(_completedKey(userId), freshCompletedIds.toList());

    return ChallengeEvaluation(
      challenges: generated,
      stats: finalStats,
      newlyCompleted: completions,
      newlyUnlockedBadges: badgeResult.newBadges,
    );
  }

  Future<void> resetDailyChallenges({required String userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = _loadCompletedChallengeIds(prefs, userId);
    final todaySuffix = _dateKey(DateTime.now());

    ids.removeWhere((id) => id.startsWith('daily_') && !id.endsWith(todaySuffix));
    ids.removeWhere((id) => id.startsWith('streak_') && !id.endsWith(todaySuffix));

    await prefs.setStringList(_completedKey(userId), ids.toList());
  }

  GamificationStats _loadStats(SharedPreferences prefs, String userId) {
    final raw = prefs.getString(_statsKey(userId));
    if (raw == null || raw.isEmpty) {
      return GamificationStats.empty;
    }

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return GamificationStats.fromMap(map);
    } catch (_) {
      return GamificationStats.empty;
    }
  }

  Set<String> _loadCompletedChallengeIds(SharedPreferences prefs, String userId) {
    return (prefs.getStringList(_completedKey(userId)) ?? const <String>[])
        .toSet();
  }

  Future<void> _resetOldChallengeRecords({
    required SharedPreferences prefs,
    required String userId,
    required DateTime now,
    required Set<String> existingIds,
  }) async {
    final today = _dateKey(now);
    final week = _weekKey(now);

    existingIds.removeWhere((id) {
      if (id.startsWith('daily_')) {
        return !id.endsWith(today);
      }
      if (id.startsWith('streak_')) {
        return !id.endsWith(today);
      }
      if (id.startsWith('weekly_')) {
        return !id.endsWith(week);
      }
      return false;
    });

    await prefs.setStringList(_completedKey(userId), existingIds.toList());
  }

  int _sumAmount(Iterable<Expense> expenses) {
    return expenses.fold(0, (sum, item) => sum + item.amount);
  }

  int _currentUnderLimitStreak({
    required List<Expense> expenses,
    required DateTime now,
    required int dailyLimit,
    required int maxDaysToCheck,
  }) {
    final byDay = <String, int>{};
    for (final expense in expenses) {
      final key = _dateKey(expense.date);
      byDay[key] = (byDay[key] ?? 0) + expense.amount;
    }

    var streak = 0;
    for (var i = 0; i < maxDaysToCheck; i++) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: i));
      final dayKey = _dateKey(day);
      if (!byDay.containsKey(dayKey)) {
        break;
      }

      final dayTotal = byDay[dayKey] ?? 0;
      if (dayTotal <= dailyLimit) {
        streak += 1;
      } else {
        break;
      }
    }
    return streak;
  }

  int _longestUnderLimitStreak({
    required List<Expense> expenses,
    required int dailyLimit,
  }) {
    if (expenses.isEmpty) {
      return 0;
    }

    final byDay = <String, int>{};
    for (final expense in expenses) {
      final key = _dateKey(expense.date);
      byDay[key] = (byDay[key] ?? 0) + expense.amount;
    }

    final sortedDays = byDay.keys.toList()..sort();
    var best = 0;
    var current = 0;
    DateTime? previousDay;

    for (final key in sortedDays) {
      final currentDay = DateTime.parse(key);
      final withinLimit = (byDay[key] ?? 0) <= dailyLimit;
      final isConsecutive = previousDay != null &&
          currentDay.difference(previousDay).inDays == 1;

      if (!withinLimit) {
        current = 0;
      } else if (previousDay == null || isConsecutive) {
        current += 1;
      } else {
        current = 1;
      }

      if (current > best) {
        best = current;
      }
      previousDay = currentDay;
    }

    return best;
  }

  int _savedAmountForChallenge({
    required Challenge challenge,
    required int todaySpent,
    required int weeklySaved,
    required int streakDays,
  }) {
    switch (challenge.challengeType) {
      case ChallengeType.daily:
        return (challenge.targetAmount - todaySpent)
            .clamp(0, challenge.targetAmount);
      case ChallengeType.weekly:
        return weeklySaved;
      case ChallengeType.streak:
        return streakDays;
    }
  }

  ({List<String> updatedBadges, List<String> newBadges}) _evaluateBadges(
    GamificationStats stats,
  ) {
    final previouslyUnlocked = stats.badgesUnlocked.toSet();
    final verifiedUnlocked = <String>{};

    void unlock(String badge) {
      verifiedUnlocked.add(badge);
    }

    if (stats.bestStreak >= 3) {
      unlock('Bronze Saver');
    }
    if (stats.bestStreak >= 7) {
      unlock('Silver Saver');
    }
    if (stats.bestStreak >= 30) {
      unlock('Gold Saver');
    }

    final unlockedNow = verifiedUnlocked.difference(previouslyUnlocked).toList()
      ..sort();

    return (
      updatedBadges: verifiedUnlocked.toList()..sort(),
      newBadges: unlockedNow,
    );
  }

  String _statsKey(String userId) => '$_statsKeyPrefix$userId';
  String _completedKey(String userId) => '$_completedKeyPrefix$userId';

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '-${date.month.toString().padLeft(2, '0')}'
        '-${date.day.toString().padLeft(2, '0')}';
  }

  String _weekKey(DateTime date) {
    final dayOfYear =
        date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    final week = ((dayOfYear - date.weekday + 10) / 7).floor();
    return '${date.year}-W${week.toString().padLeft(2, '0')}';
  }
}
