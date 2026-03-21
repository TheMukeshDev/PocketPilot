enum ChallengeType { daily, weekly, streak }

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
  });

  final String id;
  final String title;
  final String description;
  final int targetAmount;
  final int rewardPoints;
  final double progress;
  final bool isCompleted;
  final ChallengeType challengeType;

  Challenge copyWith({
    String? id,
    String? title,
    String? description,
    int? targetAmount,
    int? rewardPoints,
    double? progress,
    bool? isCompleted,
    ChallengeType? challengeType,
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
    );
  }
}

class ChallengeProgress {
  const ChallengeProgress({
    required this.challengeId,
    required this.currentProgress,
    required this.target,
    required this.isCompleted,
    required this.lastUpdatedDate,
  });

  final String challengeId;
  final int currentProgress;
  final int target;
  final bool isCompleted;
  final DateTime lastUpdatedDate;

  ChallengeProgress copyWith({
    String? challengeId,
    int? currentProgress,
    int? target,
    bool? isCompleted,
    DateTime? lastUpdatedDate,
  }) {
    return ChallengeProgress(
      challengeId: challengeId ?? this.challengeId,
      currentProgress: currentProgress ?? this.currentProgress,
      target: target ?? this.target,
      isCompleted: isCompleted ?? this.isCompleted,
      lastUpdatedDate: lastUpdatedDate ?? this.lastUpdatedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'challengeId': challengeId,
      'currentProgress': currentProgress,
      'target': target,
      'isCompleted': isCompleted,
      'lastUpdatedDate': lastUpdatedDate.toIso8601String(),
    };
  }

  factory ChallengeProgress.fromMap(Map<String, dynamic> map) {
    return ChallengeProgress(
      challengeId: map['challengeId']?.toString() ?? '',
      currentProgress: (map['currentProgress'] as num?)?.toInt() ?? 0,
      target: (map['target'] as num?)?.toInt() ?? 0,
      isCompleted: map['isCompleted'] == true,
      lastUpdatedDate:
          DateTime.tryParse(map['lastUpdatedDate']?.toString() ?? '') ??
              DateTime.now(),
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
  });

  final Challenge challenge;
  final int pointsEarned;
  final int savedAmount;
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
