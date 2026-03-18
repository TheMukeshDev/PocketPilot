class Expense {
  final int? id;
  final String? cloudId;
  final String title;
  final int amount;
  final String category;
  final DateTime date;
  final String? userId;
  final bool synced;

  Expense({
    this.id,
    this.cloudId,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.userId,
    this.synced = false,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'cloud_id': cloudId,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'user_id': userId,
      'synced': synced ? 1 : 0,
    };
  }

  Map<String, Object?> toCloudMap() {
    return {
      '_id': cloudId,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'userId': userId,
    };
  }

  factory Expense.fromMap(Map<String, Object?> map) {
    return Expense(
      id: map['id'] as int?,
      cloudId: map['cloud_id'] as String?,
      title: map['title'] as String,
      amount: map['amount'] as int,
      category: map['category'] as String,
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      userId: map['user_id'] as String?,
      synced: ((map['synced'] as int?) ?? 0) == 1,
    );
  }

  factory Expense.fromCloudMap(Map<String, dynamic> map) {
    return Expense(
      cloudId: map['_id']?.toString(),
      title: (map['title'] as String?) ?? 'Expense',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      category: (map['category'] as String?) ?? 'Other',
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      userId: map['userId']?.toString(),
      synced: true,
    );
  }

  Expense copyWith({
    int? id,
    String? cloudId,
    String? title,
    int? amount,
    String? category,
    DateTime? date,
    String? userId,
    bool? synced,
  }) {
    return Expense(
      id: id ?? this.id,
      cloudId: cloudId ?? this.cloudId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      userId: userId ?? this.userId,
      synced: synced ?? this.synced,
    );
  }
}