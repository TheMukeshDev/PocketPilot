import 'dart:convert';

enum NotificationType {
  budget,
  streak,
  reward,
  reminder,
}

enum NotificationCategory {
  budgetAlerts,
  streakUpdates,
  rewardsPoints,
  reminderNotifications,
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? metadata;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.metadata,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    NotificationType? type,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type.index,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'metadata': metadata,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      type: NotificationType.values[map['type'] as int],
      createdAt: DateTime.parse(map['createdAt'] as String),
      isRead: map['isRead'] as bool? ?? false,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory AppNotification.fromJson(String source) =>
      AppNotification.fromMap(jsonDecode(source) as Map<String, dynamic>);

  static String generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }
}

class NotificationPreferences {
  final bool masterEnabled;
  final bool budgetAlertsEnabled;
  final bool streakUpdatesEnabled;
  final bool rewardsPointsEnabled;
  final bool reminderNotificationsEnabled;

  const NotificationPreferences({
    this.masterEnabled = true,
    this.budgetAlertsEnabled = true,
    this.streakUpdatesEnabled = true,
    this.rewardsPointsEnabled = true,
    this.reminderNotificationsEnabled = true,
  });

  NotificationPreferences copyWith({
    bool? masterEnabled,
    bool? budgetAlertsEnabled,
    bool? streakUpdatesEnabled,
    bool? rewardsPointsEnabled,
    bool? reminderNotificationsEnabled,
  }) {
    return NotificationPreferences(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      budgetAlertsEnabled: budgetAlertsEnabled ?? this.budgetAlertsEnabled,
      streakUpdatesEnabled: streakUpdatesEnabled ?? this.streakUpdatesEnabled,
      rewardsPointsEnabled: rewardsPointsEnabled ?? this.rewardsPointsEnabled,
      reminderNotificationsEnabled:
          reminderNotificationsEnabled ?? this.reminderNotificationsEnabled,
    );
  }

  bool isCategoryEnabled(NotificationCategory category) {
    if (!masterEnabled) return false;
    switch (category) {
      case NotificationCategory.budgetAlerts:
        return budgetAlertsEnabled;
      case NotificationCategory.streakUpdates:
        return streakUpdatesEnabled;
      case NotificationCategory.rewardsPoints:
        return rewardsPointsEnabled;
      case NotificationCategory.reminderNotifications:
        return reminderNotificationsEnabled;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'masterEnabled': masterEnabled,
      'budgetAlertsEnabled': budgetAlertsEnabled,
      'streakUpdatesEnabled': streakUpdatesEnabled,
      'rewardsPointsEnabled': rewardsPointsEnabled,
      'reminderNotificationsEnabled': reminderNotificationsEnabled,
    };
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      masterEnabled: map['masterEnabled'] as bool? ?? true,
      budgetAlertsEnabled: map['budgetAlertsEnabled'] as bool? ?? true,
      streakUpdatesEnabled: map['streakUpdatesEnabled'] as bool? ?? true,
      rewardsPointsEnabled: map['rewardsPointsEnabled'] as bool? ?? true,
      reminderNotificationsEnabled:
          map['reminderNotificationsEnabled'] as bool? ?? true,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory NotificationPreferences.fromJson(String source) =>
      NotificationPreferences.fromMap(
          jsonDecode(source) as Map<String, dynamic>);
}

class NotificationDailyTracker {
  final String date;
  final bool overspendAlertSent;
  final bool streakAlertSent;
  final bool streakBrokenAlertSent;
  final bool rewardAlertSent;
  final bool reminderSent;
  final String? lastExpenseLogDate;

  const NotificationDailyTracker({
    required this.date,
    this.overspendAlertSent = false,
    this.streakAlertSent = false,
    this.streakBrokenAlertSent = false,
    this.rewardAlertSent = false,
    this.reminderSent = false,
    this.lastExpenseLogDate,
  });

  NotificationDailyTracker copyWith({
    String? date,
    bool? overspendAlertSent,
    bool? streakAlertSent,
    bool? streakBrokenAlertSent,
    bool? rewardAlertSent,
    bool? reminderSent,
    String? lastExpenseLogDate,
  }) {
    return NotificationDailyTracker(
      date: date ?? this.date,
      overspendAlertSent: overspendAlertSent ?? this.overspendAlertSent,
      streakAlertSent: streakAlertSent ?? this.streakAlertSent,
      streakBrokenAlertSent:
          streakBrokenAlertSent ?? this.streakBrokenAlertSent,
      rewardAlertSent: rewardAlertSent ?? this.rewardAlertSent,
      reminderSent: reminderSent ?? this.reminderSent,
      lastExpenseLogDate: lastExpenseLogDate ?? this.lastExpenseLogDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'overspendAlertSent': overspendAlertSent,
      'streakAlertSent': streakAlertSent,
      'streakBrokenAlertSent': streakBrokenAlertSent,
      'rewardAlertSent': rewardAlertSent,
      'reminderSent': reminderSent,
      'lastExpenseLogDate': lastExpenseLogDate,
    };
  }

  factory NotificationDailyTracker.fromMap(Map<String, dynamic> map) {
    return NotificationDailyTracker(
      date: map['date'] as String,
      overspendAlertSent: map['overspendAlertSent'] as bool? ?? false,
      streakAlertSent: map['streakAlertSent'] as bool? ?? false,
      streakBrokenAlertSent: map['streakBrokenAlertSent'] as bool? ?? false,
      rewardAlertSent: map['rewardAlertSent'] as bool? ?? false,
      reminderSent: map['reminderSent'] as bool? ?? false,
      lastExpenseLogDate: map['lastExpenseLogDate'] as String?,
    );
  }
}
