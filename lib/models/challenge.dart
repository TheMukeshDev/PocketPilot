enum ChallengeType { daily, monthly, streak }

class Challenge {
  const Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.targetAmount,
    required this.rewardPoints,
    required this.progress,
    required this.isCompleted,
    required this.challengeType,
    this.cycleKey = '',
    this.currentSavings = 0,
  });

  final String id;
  final String title;
  final String description;
  final int targetAmount;
  final int rewardPoints;
  final double progress;
  final bool isCompleted;
  final ChallengeType challengeType;
  final String cycleKey;
  final int currentSavings;

  Challenge copyWith({
    String? id,
    String? title,
    String? description,
    int? targetAmount,
    int? rewardPoints,
    double? progress,
    bool? isCompleted,
    ChallengeType? challengeType,
    String? cycleKey,
    int? currentSavings,
  }) {
    return Challenge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      targetAmount: targetAmount ?? this.targetAmount,
      rewardPoints: rewardPoints ?? this.rewardPoints,
      progress: progress ?? this.progress,
      isCompleted: isCompleted ?? this.isCompleted,
      challengeType: challengeType ?? this.challengeType,
      cycleKey: cycleKey ?? this.cycleKey,
      currentSavings: currentSavings ?? this.currentSavings,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'targetAmount': targetAmount,
      'rewardPoints': rewardPoints,
      'progress': progress,
      'isCompleted': isCompleted,
      'challengeType': challengeType.name,
      'cycleKey': cycleKey,
      'currentSavings': currentSavings,
    };
  }

  factory Challenge.fromMap(Map<String, dynamic> map) {
    return Challenge(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      targetAmount: ((map['targetAmount'] as dynamic)?.toInt()) ?? 0,
      rewardPoints: ((map['rewardPoints'] as dynamic)?.toInt()) ?? 0,
      progress: ((map['progress'] as dynamic)?.toDouble()) ?? 0.0,
      isCompleted: map['isCompleted'] == true,
      challengeType: ChallengeType.values.firstWhere(
        (value) => value.name == map['challengeType']?.toString(),
        orElse: () => ChallengeType.daily,
      ),
      cycleKey: map['cycleKey']?.toString() ?? '',
      currentSavings: (map['currentSavings'] as num?)?.toInt() ?? 0,
    );
  }
}

class ChallengeProgress {
  const ChallengeProgress({
    required this.challengeId,
    required this.cycleKey,
    required this.currentProgress,
    required this.target,
    required this.isCompleted,
    required this.lastUpdatedDate,
    this.pointsAwarded = false,
    this.notificationSent = false,
    this.completedAt,
  });

  final String challengeId;
  final String cycleKey;
  final int currentProgress;
  final int target;
  final bool isCompleted;
  final DateTime lastUpdatedDate;
  final bool pointsAwarded;
  final bool notificationSent;
  final DateTime? completedAt;

  factory ChallengeProgress.empty(String challengeId, String cycleKey, int target) {
    return ChallengeProgress(
      challengeId: challengeId,
      cycleKey: cycleKey,
      currentProgress: 0,
      target: target,
      isCompleted: false,
      lastUpdatedDate: DateTime.now(),
    );
  }

  ChallengeProgress copyWith({
    String? challengeId,
    String? cycleKey,
    int? currentProgress,
    int? target,
    bool? isCompleted,
    DateTime? lastUpdatedDate,
    bool? pointsAwarded,
    bool? notificationSent,
    DateTime? completedAt,
  }) {
    return ChallengeProgress(
      challengeId: challengeId ?? this.challengeId,
      cycleKey: cycleKey ?? this.cycleKey,
      currentProgress: currentProgress ?? this.currentProgress,
      target: target ?? this.target,
      isCompleted: isCompleted ?? this.isCompleted,
      lastUpdatedDate: lastUpdatedDate ?? this.lastUpdatedDate,
      pointsAwarded: pointsAwarded ?? this.pointsAwarded,
      notificationSent: notificationSent ?? this.notificationSent,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  bool get canAwardPoints => isCompleted && !pointsAwarded;
  bool get canSendNotification => isCompleted && !notificationSent;

  Map<String, dynamic> toMap() {
    return {
      'challengeId': challengeId,
      'cycleKey': cycleKey,
      'currentProgress': currentProgress,
      'target': target,
      'isCompleted': isCompleted,
      'lastUpdatedDate': lastUpdatedDate.toIso8601String(),
      'pointsAwarded': pointsAwarded,
      'notificationSent': notificationSent,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory ChallengeProgress.fromMap(Map<String, dynamic> map) {
    return ChallengeProgress(
      challengeId: map['challengeId']?.toString() ?? '',
      cycleKey: map['cycleKey']?.toString() ?? '',
      currentProgress: (map['currentProgress'] as num?)?.toInt() ?? 0,
      target: (map['target'] as num?)?.toInt() ?? 0,
      isCompleted: map['isCompleted'] == true,
      lastUpdatedDate:
          DateTime.tryParse(map['lastUpdatedDate']?.toString() ?? '') ?? DateTime.now(),
      pointsAwarded: map['pointsAwarded'] == true,
      notificationSent: map['notificationSent'] == true,
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'].toString())
          : null,
    );
  }
}

class UserGamification {
  const UserGamification({
    required this.totalPoints,
    required this.currentStreak,
    required this.bestStreak,
    required this.lastCompletedDate,
  });

  final int totalPoints;
  final int currentStreak;
  final int bestStreak;
  final DateTime? lastCompletedDate;

  static const UserGamification empty = UserGamification(
    totalPoints: 0,
    currentStreak: 0,
    bestStreak: 0,
    lastCompletedDate: null,
  );

  UserGamification copyWith({
    int? totalPoints,
    int? currentStreak,
    int? bestStreak,
    DateTime? lastCompletedDate,
  }) {
    return UserGamification(
      totalPoints: totalPoints ?? this.totalPoints,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalPoints': totalPoints,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'lastCompletedDate': lastCompletedDate?.toIso8601String(),
    };
  }

  factory UserGamification.fromMap(Map<String, dynamic> map) {
    return UserGamification(
      totalPoints: (map['totalPoints'] as num?)?.toInt() ?? 0,
      currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
      bestStreak: (map['bestStreak'] as num?)?.toInt() ?? 0,
      lastCompletedDate: map['lastCompletedDate'] != null
          ? DateTime.tryParse(map['lastCompletedDate'].toString())
          : null,
    );
  }
}

class GamificationStats {
  const GamificationStats({
    required this.totalPoints,
    required this.currentStreak,
    required this.bestStreak,
    required this.badgesUnlocked,
  });

  final int totalPoints;
  final int currentStreak;
  final int bestStreak;
  final List<String> badgesUnlocked;

  static const GamificationStats empty = GamificationStats(
    totalPoints: 0,
    currentStreak: 0,
    bestStreak: 0,
    badgesUnlocked: <String>[],
  );

  GamificationStats copyWith({
    int? totalPoints,
    int? currentStreak,
    int? bestStreak,
    List<String>? badgesUnlocked,
  }) {
    return GamificationStats(
      totalPoints: totalPoints ?? this.totalPoints,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      badgesUnlocked: badgesUnlocked ?? this.badgesUnlocked,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalPoints': totalPoints,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'badgesUnlocked': badgesUnlocked,
    };
  }

  factory GamificationStats.fromMap(Map<String, dynamic> map) {
    return GamificationStats(
      totalPoints: ((map['totalPoints'] as dynamic)?.toInt()) ?? 0,
      currentStreak: ((map['currentStreak'] as dynamic)?.toInt()) ?? 0,
      bestStreak: ((map['bestStreak'] as dynamic)?.toInt()) ?? 0,
      badgesUnlocked: ((map['badgesUnlocked'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class ChallengeCompletion {
  const ChallengeCompletion({
    required this.challenge,
    required this.pointsEarned,
    required this.savedAmount,
    required this.isNewCompletion,
  });

  final Challenge challenge;
  final int pointsEarned;
  final int savedAmount;
  final bool isNewCompletion;
}

class ChallengeEvaluation {
  const ChallengeEvaluation({
    required this.challenges,
    required this.stats,
    required this.newlyCompleted,
    required this.newlyUnlockedBadges,
  });

  final List<Challenge> challenges;
  final GamificationStats stats;
  final List<ChallengeCompletion> newlyCompleted;
  final List<String> newlyUnlockedBadges;
}

class SavingsCalculation {
  const SavingsCalculation({
    required this.totalSavings,
    required this.daysUnderBudget,
    required this.totalDays,
    required this.cycleStart,
    required this.cycleEnd,
    required this.dailyBreakdown,
  });

  final int totalSavings;
  final int daysUnderBudget;
  final int totalDays;
  final DateTime cycleStart;
  final DateTime cycleEnd;
  final Map<String, int> dailyBreakdown;

  double get progressPercentage {
    if (totalDays == 0) return 0.0;
    return (daysUnderBudget / totalDays).clamp(0.0, 1.0);
  }

  bool get isFullySaved => daysUnderBudget >= totalDays;
}
