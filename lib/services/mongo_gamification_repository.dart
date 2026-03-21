import 'package:mongo_dart/mongo_dart.dart';

import '../models/challenge.dart';
import 'app_config.dart';

class MongoGamificationRepository {
  MongoGamificationRepository._();
  static final MongoGamificationRepository instance =
      MongoGamificationRepository._();

  Db? _db;

  Future<void> _initDb() async {
    if (_db != null && _db!.isConnected) return;

    final dbUri = AppConfig.mongoUri;
    if (dbUri == null || dbUri.isEmpty) {
      throw StateError('MONGO_URI is not configured');
    }

    final dbName = AppConfig.mongoDbName;
    _db = Db('$dbUri/$dbName?retryWrites=true&w=majority');
    await _db!.open();
  }

  Future<void> saveUserGamification(
      String userId, UserGamification userGamification) async {
    try {
      await _initDb();
      final collection = _db!.collection('user_gamification');
      await collection.replaceOne(
        where.eq('userId', userId),
        {
          'userId': userId,
          'totalPoints': userGamification.totalPoints,
          'currentStreak': userGamification.currentStreak,
          'bestStreak': userGamification.bestStreak,
          'lastCompletedDate':
              userGamification.lastCompletedDate?.toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        },
        upsert: true,
      );
    } catch (_) {
      // Silent fallback to local persistence as primary source of truth.
    }
  }

  Future<void> saveChallengeProgress(
      String userId, ChallengeProgress progress) async {
    try {
      await _initDb();
      final collection = _db!.collection('challenge_progress');
      await collection.replaceOne(
        where.eq('userId', userId).eq('challengeId', progress.challengeId),
        {
          'userId': userId,
          'challengeId': progress.challengeId,
          'currentProgress': progress.currentProgress,
          'target': progress.target,
          'isCompleted': progress.isCompleted,
          'lastUpdatedDate': progress.lastUpdatedDate.toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        },
        upsert: true,
      );
    } catch (_) {
      // Silent fallback.
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
