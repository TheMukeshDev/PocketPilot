import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/challenge.dart';
import '../models/expense.dart';
import 'mongo_gamification_repository.dart';

class GamificationService {
  GamificationService._();

  static final GamificationService instance = GamificationService._();

  static const String _userGamificationKeyPrefix = 'user_gamification_';
  static const String _challengeProgressKeyPrefix = 'challenge_progress_';
  static const String _dailyCompletionsKeyPrefix = 'daily_completions_';
  static const String _gamificationTable = 'gamification_data';

  Database? _gamificationDb;

  Future<Database> get gamificationDatabase async {
    if (_gamificationDb != null) return _gamificationDb!;
    _gamificationDb = await _initGamificationDatabase();
    return _gamificationDb!;
  }

  Future<Database> _initGamificationDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/gamification.db';

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_gamificationTable (
            user_id TEXT NOT NULL,
            challenge_id TEXT NOT NULL,
            data_type TEXT NOT NULL,
            json_data TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            PRIMARY KEY (user_id, challenge_id, data_type)
          )
        ''');
      },
    );
  }

  /// Evaluate challenges with proper validation and prevent duplicate points
  Future<ChallengeEvaluation> evaluateChallenges({
    required List<Expense> expenses,
    required int dailyLimit,
    required int availableBudget,
    required String userId,
    DateTime? now,
    DateTime? cycleStart,
    DateTime? cycleEnd,
  }) async {
    final current = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    // Load current user gamification state
    final userGamification = await _loadUserGamification(prefs, userId);

    // Check if we already processed today to prevent duplicate points
    final todayKey = _dateKey(current);
    final dailyCompletions = _loadDailyCompletions(prefs, userId);
    final alreadyProcessedToday = dailyCompletions.contains(todayKey);

    // Calculate spending for today and yesterday
    final todaySpent = _calculateDaySpent(expenses, current);
    final yesterdaySpent =
        _calculateDaySpent(expenses, current.subtract(const Duration(days: 1)));

    // Day is only considered complete after 6 PM (18:00) or next day
    final actualNow = DateTime.now();
    final dayComplete = actualNow.hour >= 18 || actualNow.day != current.day;
    
    // Today's valid status - only award points if day is complete AND under limit
    final todayValid = dayComplete && todaySpent <= dailyLimit;

    // Update streak and point logic based on today performance
    final updatedGamification = _updateStreakAndPoints(
      userGamification,
      todayValid,
      alreadyProcessedToday,
      current,
    );

    // Mark today as processed once valid and points are awarded (only after day complete)
    if (todayValid && !alreadyProcessedToday) {
      dailyCompletions.add(todayKey);
      await _saveDailyCompletions(prefs, userId, dailyCompletions);
    }

    // Save updated gamification state locally
    await _saveUserGamification(prefs, userId, updatedGamification);

    // Also sync to MongoDB for auditing and manual checks
    await MongoGamificationRepository.instance.saveUserGamification(
      userId,
      updatedGamification,
    );

    // Calculate remaining budget for the cycle
    final cycleEndEffective = cycleEnd ?? DateTime(current.year, current.month + 1, 1);
    final totalSpentInCycle = _calculateCycleSpent(expenses, cycleStart, cycleEndEffective);
    final remaining = availableBudget - totalSpentInCycle;

    // Generate challenges with proper progress tracking
    final challenges = _generateChallenges(
      expenses: expenses,
      current: current,
      todaySpent: todaySpent,
      dailyLimit: dailyLimit,
      availableBudget: availableBudget,
      remaining: remaining,
      cycleEnd: cycleEndEffective,
      todayValid: todayValid,
      userGamification: updatedGamification,
    );

    // Calculate newly completed challenges and points earned
    final newlyCompleted = <ChallengeCompletion>[];
    final newlyUnlockedBadges = <String>[];

    for (final challenge in challenges) {
      if (challenge.isCompleted) {
        // Only award points if not already completed
        final progress =
            await _loadChallengeProgress(prefs, userId, challenge.id);
        if (!progress.isCompleted) {
          newlyCompleted.add(ChallengeCompletion(
            challenge: challenge,
            pointsEarned: challenge.rewardPoints,
            savedAmount:
                _calculateSavedAmount(challenge, todaySpent, yesterdaySpent),
          ));

          // Mark as completed in local SP + MongoDB
          final updatedProgress = ChallengeProgress(
            challengeId: challenge.id,
            currentProgress: challenge.targetAmount,
            target: challenge.targetAmount,
            isCompleted: true,
            lastUpdatedDate: current,
          );

          await _saveChallengeProgress(
            prefs,
            userId,
            updatedProgress,
          );

          await MongoGamificationRepository.instance.saveChallengeProgress(
            userId,
            updatedProgress,
          );
        }
      }
    }

    // Check for new badges
    final badgeResult = _evaluateBadges(updatedGamification);
    newlyUnlockedBadges.addAll(badgeResult.newBadges);

    return ChallengeEvaluation(
      challenges: challenges,
      stats: GamificationStats(
        totalPoints: updatedGamification.totalPoints,
        currentStreak: updatedGamification.currentStreak,
        bestStreak: updatedGamification.bestStreak,
        badgesUnlocked: badgeResult.updatedBadges,
      ),
      newlyCompleted: newlyCompleted,
      newlyUnlockedBadges: newlyUnlockedBadges,
    );
  }

  /// Reset daily completions for testing or manual reset
  Future<void> resetDailyCompletions({required String userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_dailyCompletionsKey(userId), []);
  }

  int _calculateDaySpent(List<Expense> expenses, DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return expenses
        .where((e) => !e.date.isBefore(dayStart) && e.date.isBefore(dayEnd))
        .fold(0, (sum, e) => sum + e.amount);
  }

  UserGamification _updateStreakAndPoints(
    UserGamification current,
    bool todayValid,
    bool alreadyProcessedToday,
    DateTime today,
  ) {
    if (!todayValid) {
      // If today fails, reset streak and do not award points.
      return current.copyWith(
        currentStreak: 0,
        lastCompletedDate: null,
      );
    }

    // Today is valid. Calculate consecutive streak.
    final lastDate = current.lastCompletedDate;
    final isConsecutive =
        lastDate != null && today.difference(lastDate).inDays == 1;
    final updatedStreak = isConsecutive ? current.currentStreak + 1 : 1;
    final updatedBestStreak =
        updatedStreak > current.bestStreak ? updatedStreak : current.bestStreak;

    var points = 0;
    if (!alreadyProcessedToday) {
      points += 20;
    }

    // Weekly reward when streak hits multiples of 7.
    if (updatedStreak > 0 && updatedStreak % 7 == 0 && !alreadyProcessedToday) {
      points += 50; // Bonus for each completed week
    }

    return current.copyWith(
      totalPoints: current.totalPoints + points,
      currentStreak: updatedStreak,
      bestStreak: updatedBestStreak,
      lastCompletedDate: today,
    );
  }

  List<Challenge> _generateChallenges({
    required List<Expense> expenses,
    required DateTime current,
    required int todaySpent,
    required int dailyLimit,
    required int availableBudget,
    required int remaining,
    required DateTime cycleEnd,
    required bool todayValid,
    required UserGamification userGamification,
  }) {
    final challenges = <Challenge>[];

    // Daily Challenge: Stay under limit today
    // During the day show progress, only mark complete after day ends
    final dailyProgress = dailyLimit > 0 
        ? (1 - (todaySpent / dailyLimit)).clamp(0.0, 1.0) 
        : 0.0;
    final dayComplete = current.hour >= 18 || DateTime.now().day != current.day;
    
    challenges.add(Challenge(
      id: 'daily_${_dateKey(current)}',
      title: 'Stay under ₹$dailyLimit today',
      description:
          'Keep today spending within your daily budget of ₹$dailyLimit.',
      targetAmount: dailyLimit,
      rewardPoints: 20,
      progress: dayComplete ? (todayValid ? 1.0 : 0.0) : dailyProgress,
      isCompleted: dayComplete && todayValid,
      challengeType: ChallengeType.daily,
    ));

    // Weekly Challenge: Save ₹300
    const weeklyTarget = 300;
    final weekStart = current.subtract(Duration(days: current.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final weekSpent = _calculateWeekSpent(expenses, weekStart, weekEnd);
    
    // Calculate weekly budget - sum of daily limits for all days in week
    final int weeklyBudget = dailyLimit * 7;
    
    // Calculate actual savings: budget minus what was spent
    final weeklySaved = (weeklyBudget - weekSpent).clamp(0, weeklyBudget);
    
    // Calculate progress as a ratio of saved vs target
    double weeklyProgress = 0.0;
    if (weeklyTarget > 0) {
      weeklyProgress = (weeklySaved / weeklyTarget).clamp(0.0, 1.0);
    }
    
    // Week is completed only when saved amount reaches target
    final weeklyCompleted = weeklySaved >= weeklyTarget;

    challenges.add(Challenge(
      id: 'weekly_${_weekKey(current)}',
      title: 'Save ₹$weeklyTarget this week',
      description: 'Stay under weekly budget and save at least ₹$weeklyTarget.',
      targetAmount: weeklyTarget,
      rewardPoints: 40,
      progress: weeklyProgress,
      isCompleted: weeklyCompleted,
      challengeType: ChallengeType.weekly,
    ));

    // Streak Challenge: 7 consecutive days
    const streakTarget = 7;
    final streakProgress =
        (userGamification.currentStreak / streakTarget).clamp(0.0, 1.0);

    challenges.add(Challenge(
      id: 'streak_${_dateKey(current)}',
      title: 'Stay under limit for $streakTarget days',
      description:
          'Maintain spending under daily limit for $streakTarget consecutive days.',
      targetAmount: streakTarget,
      rewardPoints: 60,
      progress: streakProgress,
      isCompleted: userGamification.currentStreak >= streakTarget,
      challengeType: ChallengeType.streak,
    ));

    return challenges;
  }

  int _calculateWeekSpent(
      List<Expense> expenses, DateTime weekStart, DateTime weekEnd) {
    return expenses
        .where((e) => !e.date.isBefore(weekStart) && e.date.isBefore(weekEnd))
        .fold(0, (sum, e) => sum + e.amount);
  }

  int _calculateCycleSpent(
      List<Expense> expenses, DateTime? cycleStart, DateTime cycleEnd) {
    if (cycleStart == null) return 0;
    return expenses
        .where((e) => !e.date.isBefore(cycleStart) && e.date.isBefore(cycleEnd))
        .fold(0, (sum, e) => sum + e.amount);
  }

  int _calculateSavedAmount(
      Challenge challenge, int todaySpent, int yesterdaySpent) {
    switch (challenge.challengeType) {
      case ChallengeType.daily:
        return (challenge.targetAmount - todaySpent)
            .clamp(0, challenge.targetAmount);
      case ChallengeType.weekly:
        return (challenge.targetAmount * challenge.progress).round();
      case ChallengeType.streak:
        return challenge.targetAmount;
    }
  }

  ({List<String> updatedBadges, List<String> newBadges}) _evaluateBadges(
    UserGamification gamification,
  ) {
    final previouslyUnlocked = <String>{}; // TODO: Load from somewhere
    final verifiedUnlocked = <String>{};

    void unlock(String badge) {
      verifiedUnlocked.add(badge);
    }

    if (gamification.bestStreak >= 3) {
      unlock('Bronze Saver');
    }
    if (gamification.bestStreak >= 7) {
      unlock('Silver Saver');
    }
    if (gamification.bestStreak >= 30) {
      unlock('Gold Saver');
    }

    final unlockedNow = verifiedUnlocked.difference(previouslyUnlocked).toList()
      ..sort();

    return (
      updatedBadges: verifiedUnlocked.toList()..sort(),
      newBadges: unlockedNow,
    );
  }

  Future<UserGamification> _loadUserGamification(
      SharedPreferences prefs, String userId) async {
    final raw = prefs.getString(_userGamificationKey(userId));
    if (raw == null || raw.isEmpty) {
      return UserGamification.empty;
    }

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserGamification.fromMap(map);
    } catch (_) {
      return UserGamification.empty;
    }
  }

  Future<void> _saveUserGamification(SharedPreferences prefs, String userId,
      UserGamification gamification) async {
    await prefs.setString(
        _userGamificationKey(userId), jsonEncode(gamification.toMap()));
  }

  Future<ChallengeProgress> _loadChallengeProgress(
      SharedPreferences prefs, String userId, String challengeId) async {
    final raw = prefs.getString(_challengeProgressKey(userId, challengeId));
    if (raw == null || raw.isEmpty) {
      return ChallengeProgress(
        challengeId: challengeId,
        currentProgress: 0,
        target: 0,
        isCompleted: false,
        lastUpdatedDate: DateTime.now(),
      );
    }

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ChallengeProgress.fromMap(map);
    } catch (_) {
      return ChallengeProgress(
        challengeId: challengeId,
        currentProgress: 0,
        target: 0,
        isCompleted: false,
        lastUpdatedDate: DateTime.now(),
      );
    }
  }

  Future<void> _saveChallengeProgress(SharedPreferences prefs, String userId,
      ChallengeProgress progress) async {
    await prefs.setString(
      _challengeProgressKey(userId, progress.challengeId),
      jsonEncode(progress.toMap()),
    );
  }

  Set<String> _loadDailyCompletions(SharedPreferences prefs, String userId) {
    return (prefs.getStringList(_dailyCompletionsKey(userId)) ??
            const <String>[])
        .toSet();
  }

  Future<void> _saveDailyCompletions(
      SharedPreferences prefs, String userId, Set<String> completions) async {
    await prefs.setStringList(
        _dailyCompletionsKey(userId), completions.toList());
  }

  String _userGamificationKey(String userId) =>
      '$_userGamificationKeyPrefix$userId';
  String _challengeProgressKey(String userId, String challengeId) =>
      '$_challengeProgressKeyPrefix${userId}_$challengeId';
  String _dailyCompletionsKey(String userId) =>
      '$_dailyCompletionsKeyPrefix$userId';

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '-${date.month.toString().padLeft(2, '0')}'
        '-${date.day.toString().padLeft(2, '0')}';
  }

  String _weekKey(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    final week = ((dayOfYear - date.weekday + 10) / 7).floor();
    return '${date.year}-W${week.toString().padLeft(2, '0')}';
  }

  Future<void> resetAllGamificationData(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.remove(_userGamificationKey(userId));
    await prefs.remove(_dailyCompletionsKey(userId));
    
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_challengeProgressKeyPrefix) && key.contains(userId)) {
        await prefs.remove(key);
      }
    }
    
    await _saveUserGamification(prefs, userId, UserGamification.empty);
    
    await _saveToSqlite(userId, 'reset', {
      'totalPoints': 0,
      'currentStreak': 0,
      'bestStreak': 0,
      'lastCompletedDate': null,
      'resetAt': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> getGamificationDataFromSqlite(String userId) async {
    try {
      final db = await gamificationDatabase;
      final results = await db.query(
        _gamificationTable,
        where: 'user_id = ? AND data_type = ?',
        whereArgs: [userId, 'gamification'],
      );
      
      if (results.isNotEmpty) {
        return jsonDecode(results.first['json_data'] as String) as Map<String, dynamic>;
      }
    } catch (_) {}
    
    return {};
  }

  Future<void> _saveToSqlite(String userId, String dataType, Map<String, dynamic> data) async {
    try {
      final db = await gamificationDatabase;
      await db.insert(
        _gamificationTable,
        {
          'user_id': userId,
          'challenge_id': 'main',
          'data_type': dataType,
          'json_data': jsonEncode(data),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>> recalculateFromExpenses({
    required List<Expense> expenses,
    required int dailyLimit,
    required String userId,
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    
    int currentStreak = 0;
    int bestStreak = 0;
    final byDay = <String, int>{};
    
    for (final expense in expenses) {
      final key = _dateKey(expense.date);
      byDay[key] = (byDay[key] ?? 0) + expense.amount;
    }
    
    final sortedDays = byDay.keys.toList()..sort();
    int tempStreak = 0;
    DateTime? previousDay;
    
    for (final dayKey in sortedDays) {
      final dayTotal = byDay[dayKey] ?? 0;
      final dayDate = DateTime.parse(dayKey);
      
      if (dayTotal <= dailyLimit) {
        if (previousDay != null && dayDate.difference(previousDay).inDays == 1) {
          tempStreak++;
        } else {
          tempStreak = 1;
        }
        
        if (tempStreak > bestStreak) {
          bestStreak = tempStreak;
        }
      } else {
        tempStreak = 0;
      }
      
      previousDay = dayDate;
    }
    
    currentStreak = 0;
    for (var i = 0; i < 30; i++) {
      final day = DateTime(current.year, current.month, current.day).subtract(Duration(days: i));
      final dayKey = _dateKey(day);
      final dayTotal = byDay[dayKey] ?? 0;
      
      if (dayTotal <= dailyLimit) {
        currentStreak++;
      } else {
        break;
      }
    }
    
    const weeklyTarget = 300;
    final weekStart = current.subtract(Duration(days: current.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final weekSpent = _calculateWeekSpent(expenses, weekStart, weekEnd);
    final weeklyBudget = dailyLimit * 7;
    final weeklySaved = (weeklyBudget - weekSpent).clamp(0, weeklyBudget);
    
    int totalPointsEarned = 0;
    
    for (final dayKey in sortedDays) {
      final dayTotal = byDay[dayKey] ?? 0;
      if (dayTotal <= dailyLimit) {
        totalPointsEarned += 20;
      }
    }
    
    if (bestStreak > 0 && bestStreak % 7 == 0) {
      totalPointsEarned += (bestStreak ~/ 7) * 50;
    }
    
    if (weeklySaved >= weeklyTarget) {
      totalPointsEarned += 40;
    }
    
    if (currentStreak >= 7) {
      totalPointsEarned += 60;
    }
    
    final result = {
      'totalPoints': totalPointsEarned,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'weeklySaved': weeklySaved,
      'weeklyTarget': weeklyTarget,
      'weeklyBudget': weeklyBudget,
      'weekSpent': weekSpent,
      'calculatedAt': DateTime.now().toIso8601String(),
    };
    
    await _saveToSqlite(userId, 'gamification', result);
    
    final prefs = await SharedPreferences.getInstance();
    final updatedGamification = UserGamification(
      totalPoints: totalPointsEarned,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      lastCompletedDate: currentStreak > 0 ? current : null,
    );
    await _saveUserGamification(prefs, userId, updatedGamification);
    
    return result;
  }

  Future<GamificationStats> getVerifiedStats(String userId) async {
    final sqliteData = await getGamificationDataFromSqlite(userId);
    
    if (sqliteData.isNotEmpty) {
      return GamificationStats(
        totalPoints: (sqliteData['totalPoints'] as num?)?.toInt() ?? 0,
        currentStreak: (sqliteData['currentStreak'] as num?)?.toInt() ?? 0,
        bestStreak: (sqliteData['bestStreak'] as num?)?.toInt() ?? 0,
        badgesUnlocked: <String>[],
      );
    }
    
    final prefs = await SharedPreferences.getInstance();
    return _loadGamificationStats(prefs, userId);
  }

  GamificationStats _loadGamificationStats(SharedPreferences prefs, String userId) {
    final raw = prefs.getString(_userGamificationKey(userId));
    if (raw == null || raw.isEmpty) {
      return GamificationStats.empty;
    }

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return GamificationStats(
        totalPoints: (map['totalPoints'] as num?)?.toInt() ?? 0,
        currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
        bestStreak: (map['bestStreak'] as num?)?.toInt() ?? 0,
        badgesUnlocked: <String>[],
      );
    } catch (_) {
      return GamificationStats.empty;
    }
  }
}
