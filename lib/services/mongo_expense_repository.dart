import 'package:mongo_dart/mongo_dart.dart';

import '../models/expense.dart';
import 'app_config.dart';

class MongoExpenseRepository {
  MongoExpenseRepository._();
  static final MongoExpenseRepository instance = MongoExpenseRepository._();

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

  Future<void> upsertExpense(Expense expense) async {
    if (expense.userId == null || expense.userId!.isEmpty) return;

    try {
      await _initDb();
      final collection = _db!.collection('expenses');
      final key = where
          .eq('userId', expense.userId)
          .eq('title', expense.title)
          .eq('amount', expense.amount)
          .eq('date', expense.date.toIso8601String());

      final existing = await collection.findOne(key);
      final cloudAsset = {
        'userId': expense.userId,
        'title': expense.title,
        'amount': expense.amount,
        'category': expense.category,
        'date': expense.date.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (existing != null) {
        final objectId = existing['_id'] as ObjectId?;
        if (objectId != null) {
          await collection.replaceOne(
              where.id(objectId), {...existing, ...cloudAsset},
              upsert: true);
        } else {
          await collection.replaceOne(key, cloudAsset, upsert: true);
        }
      } else {
        await collection.insertOne(cloudAsset);
      }
    } catch (_) {
      // Swallow Mongo failures to keep app responsive and local-first.
    }
  }

  Future<List<Expense>> fetchUserExpenses(String userId) async {
    if (userId.isEmpty) {
      return [];
    }

    try {
      await _initDb();
      final collection = _db!.collection('expenses');
      final docs = await collection
          .find(where.eq('userId', userId).sortBy('date', descending: true))
          .toList();
      return docs.map((doc) => Expense.fromCloudMap(doc)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
