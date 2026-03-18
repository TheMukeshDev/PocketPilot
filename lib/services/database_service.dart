import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/expense.dart';

abstract class ExpenseStore {
  Future<Database> initDatabase();
  Future<Expense> insertExpense(Expense expense);
  Future<List<Expense>> getExpenses(String? userId);
  Future<void> deleteExpense(int id);
  Future<void> markSynced(int id);
}

class DatabaseService implements ExpenseStore {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  static const String _databaseName = 'budget_tracker.db';
  static const String _expensesTable = 'expenses';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await initDatabase();
    return _database!;
  }

  @override
  Future<Database> initDatabase() async {
    if (_database != null) {
      return _database!;
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = '${documentsDirectory.path}/$_databaseName';

    _database = await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_expensesTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cloud_id TEXT,
            title TEXT NOT NULL,
            amount INTEGER NOT NULL,
            category TEXT NOT NULL,
            date TEXT NOT NULL,
            userId TEXT,
            user_id TEXT,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _addColumnIfMissing(db, _expensesTable, 'date', 'TEXT NOT NULL DEFAULT ""');
          await _addColumnIfMissing(db, _expensesTable, 'user_id', 'TEXT');
          await _addColumnIfMissing(db, _expensesTable, 'synced', 'INTEGER NOT NULL DEFAULT 0');
        }

        if (oldVersion < 3) {
          await _addColumnIfMissing(db, _expensesTable, 'userId', 'TEXT');
        }

        if (oldVersion < 4) {
          await _addColumnIfMissing(db, _expensesTable, 'cloud_id', 'TEXT');
        }
      },
    );

    await _ensureExpenseTableSchema(_database!);

    return _database!;
  }

  Future<void> _ensureExpenseTableSchema(Database db) async {
    await _addColumnIfMissing(db, _expensesTable, 'cloud_id', 'TEXT');
    await _addColumnIfMissing(db, _expensesTable, 'userId', 'TEXT');
    await _addColumnIfMissing(db, _expensesTable, 'user_id', 'TEXT');
    await _addColumnIfMissing(db, _expensesTable, 'synced', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, _expensesTable, 'date', 'TEXT NOT NULL DEFAULT ""');
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info($table)');
    final hasColumn = tableInfo.any((entry) => entry['name'] == column);
    if (!hasColumn) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  @override
  Future<Expense> insertExpense(Expense expense) async {
    final db = await database;
    await _ensureExpenseTableSchema(db);
    final payload = Map<String, Object?>.from(expense.toMap())
      ..['userId'] = expense.userId
      ..['user_id'] = expense.userId
      ..['synced'] = expense.synced ? 1 : 0;

    final id = await db.insert(_expensesTable, payload);
    return expense.copyWith(id: id);
  }

  @override
  Future<List<Expense>> getExpenses(String? userId) async {
    final db = await database;

    final maps = userId == null
        ? await db.query(_expensesTable, orderBy: 'date DESC, id DESC')
        : await db.query(
            _expensesTable,
            where: 'userId = ? OR user_id = ? OR userId IS NULL OR user_id IS NULL',
            whereArgs: [userId, userId],
            orderBy: 'date DESC, id DESC',
          );

    return maps.map(Expense.fromMap).toList();
  }

  Future<List<Expense>> getExpensesForUser(String userId) async {
    return getExpenses(userId);
  }

  Future<List<Expense>> getUnsyncedExpenses(String userId) async {
    final db = await database;
    final maps = await db.query(
      _expensesTable,
      where:
          '(userId = ? OR user_id = ? OR userId IS NULL OR user_id IS NULL) AND synced = 0',
      whereArgs: [userId, userId],
      orderBy: 'id ASC',
    );

    return maps.map(Expense.fromMap).toList();
  }

  @override
  Future<void> markSynced(int id) async {
    final db = await database;
    await db.update(
      _expensesTable,
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markExpenseSynced(
    int localId, {
    String? cloudId,
  }) async {
    final db = await database;
    await db.update(
      _expensesTable,
      {
        'synced': 1,
        'cloud_id': cloudId,
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> upsertCloudExpenses(
    List<Expense> cloudExpenses,
    String userId,
  ) async {
    final db = await database;

    for (final expense in cloudExpenses) {
      final cloudId = expense.cloudId;
      if (cloudId == null || cloudId.isEmpty) {
        continue;
      }

      final existing = await db.query(
        _expensesTable,
        where: 'cloud_id = ?',
        whereArgs: [cloudId],
      );

      final payload = expense.copyWith(userId: userId, synced: true).toMap()
        ..remove('id')
        ..['userId'] = userId
        ..['user_id'] = userId;

      if (existing.isEmpty) {
        await db.insert(_expensesTable, payload);
      } else {
        await db.update(
          _expensesTable,
          payload,
          where: 'cloud_id = ?',
          whereArgs: [cloudId],
        );
      }
    }
  }

  @override
  Future<void> deleteExpense(int id) async {
    final db = await database;
    await db.delete(
      _expensesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}