import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/challenge.dart';
import '../models/expense.dart';
import 'app_logger.dart';

class GamificationService {
  GamificationService._();

  static final GamificationService instance = GamificationService._();

  static const String _userGamificationKeyPrefix = 'user_gamification_';
  static const String _challengeProgressKeyPrefix = 'challenge_progress_';
  static const String _dailyCompletionsKeyPrefix = 'daily_completions_';
  static const String _gamificationTable = 'gamification_data';

  static const int dailyRewardPoints = 20;
  static const int weeklyRewardPoints = 40;
  static const int monthlyRewardPoints = 60;
  static const int streakRewardPoints = 60;
  static const int weeklyStreakBonus = 50;

  static const int weeklyTarget = 300;
  static const int monthlyTarget = 500;

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
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_gamificationTable (
            user_id TEXT NOT NULL,
            challenge_id TEXT NOT NULL,
            cycle_key TEXT NOT NULL,
            data_type TEXT NOT NULL,
            json_data TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            PRIMARY KEY (user_id, challenge_id, cycle_key, data_type)
          )
        ''');
        await db.execute('''
          CREATE TABLE points_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            challenge_id TEXT NOT NULL,
            cycle_key TEXT NOT NULL,
            challenge_type TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            points_earned INTEGER NOT NULL,
            saved_amount INTEGER NOT NULL,
            earned_at TEXT NOT NULL,
            UNIQUE(user_id, challenge_id, cycle_key)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS points_history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT NOT NULL,
              challenge_id TEXT NOT NULL,
              cycle_key TEXT NOT NULL,
              challenge_type TEXT NOT NULL,
              title TEXT NOT NULL,
              description TEXT NOT NULL,
              points_earned INTEGER NOT NULL,
              saved_amount INTEGER NOT NULL,
              earned_at TEXT NOT NULL,
              UNIQUE(user_id, challenge_id, cycle_key)
            )
          ''');
        }
      },
    );
  }

  String _getDailyCycleKey(DateTime date) => 'daily_${_dateKey(date)}';

  String _getWeeklyCycleKey(DateTime date, {DateTime? cycleStart}) {
    if (cycleStart != null) {
      final daysSinceCycleStart = date.difference(cycleStart).inDays;
      final weekNumber = (daysSinceCycleStart ~/ 7) + 1;
      final monthPart = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      return 'weekly_${monthPart}_W$weekNumber';
    }
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    final week = ((dayOfYear - date.weekday + 10) / 7).floor();
    return 'weekly_${date.year}-W${week.toString().padLeft(2, '0')}';
  }

  String _getMonthlyCycleKey(DateTime date, {DateTime? cycleStart}) {
    if (cycleStart != null) {
      final monthsSinceStart = (date.year - cycleStart.year) * 12 + (date.month - cycleStart.month);
      final cycleMonth = DateTime(cycleStart.year, cycleStart.month + monthsSinceStart, 1);
      return 'monthly_${cycleMonth.year}-${cycleMonth.month.toString().padLeft(2, '0')}';
    }
    return 'monthly_${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  String _getStreakCycleKey(DateTime date) => 'streak_${_dateKey(date)}';

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '-${date.month.toString().padLeft(2, '0')}'
        '-${date.day.toString().padLeft(2, '0')}';
  }

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

    _logDebug('evaluateChallenges', {
      'userId': userId,
      'currentDate': current.toIso8601String(),
      'cycleStart': cycleStart?.toIso8601String(),
      'cycleEnd': cycleEnd?.toIso8601String(),
      'dailyLimit': dailyLimit,
      'expenseCount': expenses.length,
    });

    final userGamification = await _loadUserGamification(prefs, userId);
    final todayKey = _dateKey(current);
    final dailyCompletions = _loadDailyCompletions(prefs, userId);
    final alreadyProcessedToday = dailyCompletions.contains(todayKey);

    final todaySpent = _calculateDaySpent(expenses, current);

    final actualNow = DateTime.now();
    final dayComplete = actualNow.hour >= 18 || actualNow.day != current.day;
    final todayValid = dayComplete && todaySpent <= dailyLimit;

    final updatedGamification = _updateStreakAndPoints(
      userGamification,
      todayValid,
      alreadyProcessedToday,
      current,
    );

    if (todayValid && !alreadyProcessedToday) {
      dailyCompletions.add(todayKey);
      await _saveDailyCompletions(prefs, userId, dailyCompletions);
    }

    await _saveUserGamification(prefs, userId, updatedGamification);

    final challenges = _generateAllChallenges(
      expenses: expenses,
      current: current,
      todaySpent: todaySpent,
      dailyLimit: dailyLimit,
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
      userGamification: updatedGamification,
    );

    final newlyCompleted = <ChallengeCompletion>[];

    for (final challenge in challenges) {
      final progress = await _loadChallengeProgress(prefs, userId, challenge.id, challenge.cycleKey);
      
      if (challenge.isCompleted && !progress.isCompleted) {
        final savedAmt = _calculateSavedAmount(challenge, expenses, current, dailyLimit, cycleStart);
        
        _logDebug('challenge_completed', {
          'challengeId': challenge.id,
          'cycleKey': challenge.cycleKey,
          'savedAmount': savedAmt,
          'pointsToAward': challenge.rewardPoints,
        });

        final updatedProgress = progress.copyWith(
          isCompleted: true,
          currentProgress: challenge.currentSavings,
          completedAt: current,
          lastUpdatedDate: current,
        );

        await _saveChallengeProgress(prefs, userId, updatedProgress);

        newlyCompleted.add(ChallengeCompletion(
          challenge: challenge,
          pointsEarned: challenge.rewardPoints,
          savedAmount: savedAmt,
          isNewCompletion: true,
        ));
      }
    }

    final badgeResult = _evaluateBadges(updatedGamification);

    return ChallengeEvaluation(
      challenges: challenges,
      stats: GamificationStats(
        totalPoints: updatedGamification.totalPoints,
        currentStreak: updatedGamification.currentStreak,
        bestStreak: updatedGamification.bestStreak,
        badgesUnlocked: badgeResult.updatedBadges,
      ),
      newlyCompleted: newlyCompleted,
      newlyUnlockedBadges: badgeResult.newBadges,
    );
  }

  List<Challenge> _generateAllChallenges({
    required List<Expense> expenses,
    required DateTime current,
    required int todaySpent,
    required int dailyLimit,
    DateTime? cycleStart,
    DateTime? cycleEnd,
    required UserGamification userGamification,
  }) {
    final challenges = <Challenge>[];

    final effectiveCycleStart = cycleStart ?? DateTime(current.year, current.month, 1);
    final effectiveCycleEnd = cycleEnd ?? DateTime(current.year, current.month + 1, 1);

    challenges.add(_generateDailyChallenge(current, todaySpent, dailyLimit));

    final weeklySavings = _calculateWeeklySavings(
      expenses: expenses,
      current: current,
      dailyLimit: dailyLimit,
      cycleStart: effectiveCycleStart,
    );
    challenges.add(_generateWeeklyChallenge(current, weeklySavings, cycleStart: effectiveCycleStart));

    final monthlySavings = _calculateMonthlySavings(
      expenses: expenses,
      current: current,
      dailyLimit: dailyLimit,
      cycleStart: effectiveCycleStart,
      cycleEnd: effectiveCycleEnd,
    );
    challenges.add(_generateMonthlyChallenge(current, monthlySavings, cycleStart: effectiveCycleStart, cycleEnd: effectiveCycleEnd));

    challenges.add(_generateStreakChallenge(current, userGamification));

    return challenges;
  }

  Challenge _generateDailyChallenge(DateTime current, int todaySpent, int dailyLimit) {
    final dailyProgress = dailyLimit > 0
        ? (1 - (todaySpent / dailyLimit)).clamp(0.0, 1.0)
        : 0.0;
    final dayComplete = current.hour >= 18 || DateTime.now().day != current.day;
    final todayValid = dayComplete && todaySpent <= dailyLimit;

    return Challenge(
      id: _getDailyCycleKey(current),
      title: 'Stay under ₹$dailyLimit today',
      description: 'Keep today spending within your daily budget of ₹$dailyLimit.',
      targetAmount: dailyLimit,
      rewardPoints: dailyRewardPoints,
      progress: dayComplete ? (todayValid ? 1.0 : 0.0) : dailyProgress,
      isCompleted: dayComplete && todayValid,
      challengeType: ChallengeType.daily,
      cycleKey: _getDailyCycleKey(current),
      currentSavings: todayValid ? (dailyLimit - todaySpent).clamp(0, dailyLimit) : 0,
    );
  }

  SavingsCalculation _calculateWeeklySavings({
    required List<Expense> expenses,
    required DateTime current,
    required int dailyLimit,
    required DateTime cycleStart,
  }) {
    final currentDateOnly = DateTime(current.year, current.month, current.day);
    
    int totalSaved = 0;
    int daysUnderBudget = 0;
    final dailyBreakdown = <String, int>{};
    
    for (int i = 0; i < 7; i++) {
      final day = currentDateOnly.subtract(Duration(days: i));
      final daySpent = _calculateDaySpent(expenses, day);
      final daySaved = (dailyLimit - daySpent).clamp(0, dailyLimit);
      
      dailyBreakdown[_dateKey(day)] = daySaved;
      totalSaved += daySaved;
      
      if (daySpent <= dailyLimit) {
        daysUnderBudget++;
      }
    }

    return SavingsCalculation(
      totalSavings: totalSaved,
      daysUnderBudget: daysUnderBudget,
      totalDays: 7,
      cycleStart: currentDateOnly.subtract(const Duration(days: 6)),
      cycleEnd: currentDateOnly,
      dailyBreakdown: dailyBreakdown,
    );
  }

  Challenge _generateWeeklyChallenge(DateTime current, SavingsCalculation savings, {DateTime? cycleStart}) {
    final weeklyId = _getWeeklyCycleKey(current, cycleStart: cycleStart);
    final progress = (savings.totalSavings / weeklyTarget).clamp(0.0, 1.0);
    final isCompleted = savings.totalSavings >= weeklyTarget && savings.isFullySaved;

    return Challenge(
      id: weeklyId,
      title: 'Save ₹$weeklyTarget this week',
      description: 'Stay under daily budget for all 7 days to earn ₹$weeklyTarget in savings.',
      targetAmount: weeklyTarget,
      rewardPoints: weeklyRewardPoints,
      progress: progress,
      isCompleted: isCompleted,
      challengeType: ChallengeType.weekly,
      cycleKey: weeklyId,
      currentSavings: savings.totalSavings,
    );
  }

  SavingsCalculation _calculateMonthlySavings({
    required List<Expense> expenses,
    required DateTime current,
    required int dailyLimit,
    required DateTime cycleStart,
    required DateTime cycleEnd,
  }) {
    final availableDays = current.difference(cycleStart).inDays + 1;
    
    int totalSaved = 0;
    int daysUnderBudget = 0;
    final dailyBreakdown = <String, int>{};
    
    DateTime day = cycleStart;
    while (!day.isAfter(current) && !day.isAfter(cycleEnd)) {
      final daySpent = _calculateDaySpent(expenses, day);
      final daySaved = (dailyLimit - daySpent).clamp(0, dailyLimit);
      
      dailyBreakdown[_dateKey(day)] = daySaved;
      totalSaved += daySaved;
      
      if (daySpent <= dailyLimit) {
        daysUnderBudget++;
      }
      
      day = day.add(const Duration(days: 1));
    }

    return SavingsCalculation(
      totalSavings: totalSaved,
      daysUnderBudget: daysUnderBudget,
      totalDays: availableDays,
      cycleStart: cycleStart,
      cycleEnd: current,
      dailyBreakdown: dailyBreakdown,
    );
  }

  Challenge _generateMonthlyChallenge(DateTime current, SavingsCalculation savings, {DateTime? cycleStart, DateTime? cycleEnd}) {
    final monthlyId = _getMonthlyCycleKey(current, cycleStart: cycleStart);
    final progress = (savings.totalSavings / monthlyTarget).clamp(0.0, 1.0);
    final isCompleted = savings.totalSavings >= monthlyTarget && savings.isFullySaved;

    return Challenge(
      id: monthlyId,
      title: 'Save ₹$monthlyTarget this month',
      description: 'Stay under daily budget throughout the month to earn ₹$monthlyTarget in savings.',
      targetAmount: monthlyTarget,
      rewardPoints: monthlyRewardPoints,
      progress: progress,
      isCompleted: isCompleted,
      challengeType: ChallengeType.monthly,
      cycleKey: monthlyId,
      currentSavings: savings.totalSavings,
    );
  }

  Challenge _generateStreakChallenge(DateTime current, UserGamification userGamification) {
    const streakTarget = 7;
    final streakProgress = (userGamification.currentStreak / streakTarget).clamp(0.0, 1.0);

    return Challenge(
      id: _getStreakCycleKey(current),
      title: 'Stay under limit for $streakTarget days',
      description: 'Maintain spending under daily limit for $streakTarget consecutive days.',
      targetAmount: streakTarget,
      rewardPoints: streakRewardPoints,
      progress: streakProgress,
      isCompleted: userGamification.currentStreak >= streakTarget,
      challengeType: ChallengeType.streak,
      cycleKey: _getStreakCycleKey(current),
      currentSavings: userGamification.currentStreak,
    );
  }

  int _calculateDaySpent(List<Expense> expenses, DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return expenses
        .where((e) => !e.date.isBefore(dayStart) && e.date.isBefore(dayEnd))
        .fold(0, (sum, e) => sum + e.amount);
  }

  int _calculateSavedAmount(Challenge challenge, List<Expense> expenses, DateTime current, int dailyLimit, DateTime? cycleStart) {
    switch (challenge.challengeType) {
      case ChallengeType.daily:
        return challenge.currentSavings;
      case ChallengeType.weekly:
        return challenge.currentSavings;
      case ChallengeType.monthly:
        return challenge.currentSavings;
      case ChallengeType.streak:
        return challenge.currentSavings;
    }
  }

  UserGamification _updateStreakAndPoints(
    UserGamification current,
    bool todayValid,
    bool alreadyProcessedToday,
    DateTime today,
  ) {
    if (!todayValid) {
      return current.copyWith(
        currentStreak: 0,
        lastCompletedDate: null,
      );
    }

    final lastDate = current.lastCompletedDate;
    final isConsecutive = lastDate != null && today.difference(lastDate).inDays == 1;
    final updatedStreak = isConsecutive ? current.currentStreak + 1 : 1;
    final updatedBestStreak = updatedStreak > current.bestStreak ? updatedStreak : current.bestStreak;

    var points = 0;
    if (!alreadyProcessedToday) {
      points += dailyRewardPoints;

      if (updatedStreak > 0 && updatedStreak % 7 == 0) {
        points += weeklyStreakBonus;
        _logDebug('weekly_streak_bonus', {
          'streak': updatedStreak,
          'bonusPoints': weeklyStreakBonus,
        });
      }
    }

    return current.copyWith(
      totalPoints: current.totalPoints + points,
      currentStreak: updatedStreak,
      bestStreak: updatedBestStreak,
      lastCompletedDate: today,
    );
  }

  ({List<String> updatedBadges, List<String> newBadges}) _evaluateBadges(UserGamification gamification) {
    final verifiedUnlocked = <String>{};

    if (gamification.bestStreak >= 3) verifiedUnlocked.add('Bronze Saver');
    if (gamification.bestStreak >= 7) verifiedUnlocked.add('Silver Saver');
    if (gamification.bestStreak >= 30) verifiedUnlocked.add('Gold Saver');
    if (gamification.totalPoints >= 100) verifiedUnlocked.add('Point Collector');
    if (gamification.totalPoints >= 500) verifiedUnlocked.add('Point Master');

    return (
      updatedBadges: verifiedUnlocked.toList()..sort(),
      newBadges: verifiedUnlocked.where((b) => !gamification.bestStreak.toString().contains(b)).toList(),
    );
  }

  Future<UserGamification> _loadUserGamification(SharedPreferences prefs, String userId) async {
    final raw = prefs.getString(_userGamificationKey(userId));
    if (raw == null || raw.isEmpty) return UserGamification.empty;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserGamification.fromMap(map);
    } catch (_) {
      return UserGamification.empty;
    }
  }

  Future<void> _saveUserGamification(SharedPreferences prefs, String userId, UserGamification gamification) async {
    await prefs.setString(_userGamificationKey(userId), jsonEncode(gamification.toMap()));
  }

  Future<ChallengeProgress> _loadChallengeProgress(
    SharedPreferences prefs,
    String userId,
    String challengeId,
    String cycleKey,
  ) async {
    final raw = prefs.getString(_challengeProgressKey(userId, challengeId));
    if (raw == null || raw.isEmpty) {
      return ChallengeProgress.empty(challengeId, cycleKey, 0);
    }

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final progress = ChallengeProgress.fromMap(map);
      if (progress.cycleKey != cycleKey) {
        _logDebug('cycle_key_mismatch', {
          'expected': cycleKey,
          'found': progress.cycleKey,
          'resetting': true,
        });
        return ChallengeProgress.empty(challengeId, cycleKey, 0);
      }
      return progress;
    } catch (_) {
      return ChallengeProgress.empty(challengeId, cycleKey, 0);
    }
  }

  Future<void> _saveChallengeProgress(SharedPreferences prefs, String userId, ChallengeProgress progress) async {
    await prefs.setString(
      _challengeProgressKey(userId, progress.challengeId),
      jsonEncode(progress.toMap()),
    );
  }

  Set<String> _loadDailyCompletions(SharedPreferences prefs, String userId) {
    return (prefs.getStringList(_dailyCompletionsKey(userId)) ?? const <String>[]).toSet();
  }

  Future<void> _saveDailyCompletions(SharedPreferences prefs, String userId, Set<String> completions) async {
    await prefs.setStringList(_dailyCompletionsKey(userId), completions.toList());
  }

  String _userGamificationKey(String userId) => '$_userGamificationKeyPrefix$userId';
  String _challengeProgressKey(String userId, String challengeId) => '$_challengeProgressKeyPrefix${userId}_$challengeId';
  String _dailyCompletionsKey(String userId) => '$_dailyCompletionsKeyPrefix$userId';

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
    
    _logDebug('gamification_reset', {'userId': userId});
  }

  Future<void> logPointsHistory({
    required String userId,
    required Challenge challenge,
    required int pointsEarned,
    required int savedAmount,
    required DateTime earnedAt,
  }) async {
    try {
      final db = await gamificationDatabase;
      await db.insert(
        'points_history',
        {
          'user_id': userId,
          'challenge_id': challenge.id,
          'cycle_key': challenge.cycleKey,
          'challenge_type': challenge.challengeType.name,
          'title': challenge.title,
          'description': challenge.description,
          'points_earned': pointsEarned,
          'saved_amount': savedAmount,
          'earned_at': earnedAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      _logDebug('points_history_logged', {
        'userId': userId,
        'challengeId': challenge.id,
        'cycleKey': challenge.cycleKey,
        'pointsEarned': pointsEarned,
        'savedAmount': savedAmount,
      });
    } catch (e) {
      _logDebug('points_history_error', {'error': e.toString()});
    }
  }

  Future<List<PointsHistoryEntry>> getPointsHistory(String userId, {int limit = 50}) async {
    try {
      final db = await gamificationDatabase;
      final results = await db.query(
        'points_history',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'earned_at DESC',
        limit: limit,
      );
      
      return results.map((row) => PointsHistoryEntry(
        id: row['id'].toString(),
        challengeId: row['challenge_id'] as String,
        challengeType: ChallengeType.values.firstWhere(
          (v) => v.name == row['challenge_type'],
          orElse: () => ChallengeType.daily,
        ),
        title: row['title'] as String,
        description: row['description'] as String,
        pointsEarned: row['points_earned'] as int,
        savedAmount: row['saved_amount'] as int,
        earnedAt: DateTime.parse(row['earned_at'] as String),
        cycleKey: row['cycle_key'] as String,
      )).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> hasCompletedChallenge(String userId, String challengeId, String cycleKey) async {
    try {
      final db = await gamificationDatabase;
      final result = await db.query(
        'points_history',
        where: 'user_id = ? AND challenge_id = ? AND cycle_key = ?',
        whereArgs: [userId, challengeId, cycleKey],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<int> getTotalPointsFromHistory(String userId) async {
    try {
      final db = await gamificationDatabase;
      final result = await db.rawQuery(
        'SELECT SUM(points_earned) as total FROM points_history WHERE user_id = ?',
        [userId],
      );
      return (result.first['total'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> resetDailyCompletions({required String userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_dailyCompletionsKey(userId), []);
  }

  void _logDebug(String event, Map<String, dynamic> data) {
    AppLogger.instance.debug('GamificationService', event, context: data);
  }

  Future<GamificationStats> getVerifiedStats(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return _loadGamificationStats(prefs, userId);
  }

  GamificationStats _loadGamificationStats(SharedPreferences prefs, String userId) {
    final raw = prefs.getString(_userGamificationKey(userId));
    if (raw == null || raw.isEmpty) return GamificationStats.empty;

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
    
    final savings = _calculateWeeklySavings(
      expenses: expenses,
      current: current,
      dailyLimit: dailyLimit,
      cycleStart: DateTime(current.year, current.month, 1),
    );
    
    int totalPointsEarned = 0;
    
    for (final dayKey in sortedDays) {
      final dayTotal = byDay[dayKey] ?? 0;
      if (dayTotal <= dailyLimit) {
        totalPointsEarned += dailyRewardPoints;
      }
    }
    
    if (bestStreak > 0 && bestStreak % 7 == 0) {
      totalPointsEarned += (bestStreak ~/ 7) * weeklyStreakBonus;
    }
    
    if (savings.totalSavings >= weeklyTarget) {
      totalPointsEarned += weeklyRewardPoints;
    }
    
    if (currentStreak >= 7) {
      totalPointsEarned += streakRewardPoints;
    }
    
    final result = {
      'totalPoints': totalPointsEarned,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'weeklySaved': savings.totalSavings,
      'weeklyTarget': weeklyTarget,
      'calculatedAt': DateTime.now().toIso8601String(),
    };
    
    final prefs = await SharedPreferences.getInstance();
    final updatedGamification = UserGamification(
      totalPoints: totalPointsEarned,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      lastCompletedDate: currentStreak > 0 ? current : null,
    );
    await _saveUserGamification(prefs, userId, updatedGamification);
    
    _logDebug('recalculated_gamification', {
      'userId': userId,
      'totalPoints': totalPointsEarned,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
    });
    
    return result;
  }
}
