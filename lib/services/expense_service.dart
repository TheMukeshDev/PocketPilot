import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/expense.dart';
import '../models/user.dart';
import 'app_config.dart';
import 'database_service.dart';
import 'mongo_expense_repository.dart';

class ExpenseService {
  ExpenseService._();

  static final ExpenseService instance = ExpenseService._();
  static const Duration _syncTimeout = Duration(seconds: 8);
  bool _cloudSyncDisabledForSession = false;

  final DatabaseService _databaseService = DatabaseService.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Future<List<Expense>> getExpensesForUser(AppUser? user) async {
    if (user == null) {
      return _databaseService.getExpenses(null);
    }

    return _databaseService.getExpensesForUser(user.id);
  }

  Future<Expense> addExpense(Expense expense, AppUser? user) async {
    final localExpense = expense.copyWith(
      userId: user?.id,
      synced: false,
    );

    final saved = await _databaseService.insertExpense(localExpense);

    if (user != null && !_cloudSyncDisabledForSession) {
      await _trySyncSingleExpense(saved, user);
    }

    return saved;
  }

  Future<void> deleteExpense(Expense expense) async {
    final id = expense.id;
    if (id == null) {
      return;
    }
    await _databaseService.deleteExpense(id);
  }

  Future<void> updateExpense(Expense expense) async {
    if (expense.id == null) return;
    await _databaseService.updateExpense(expense);
  }

  Future<List<Expense>> syncAndFetch(AppUser? user) async {
    if (user == null) {
      return _databaseService.getExpenses(null);
    }

    if (_cloudSyncDisabledForSession) {
      return _databaseService.getExpensesForUser(user.id);
    }

    await _syncUnsyncedExpenses(user);
    await _pullCloudExpenses(user);

    return _databaseService.getExpensesForUser(user.id);
  }

  Future<void> syncNow(AppUser? user) async {
    if (user == null) {
      return;
    }

    if (_cloudSyncDisabledForSession) {
      return;
    }

    await _syncUnsyncedExpenses(user);
    await _pullCloudExpenses(user);
  }

  Future<void> _syncUnsyncedExpenses(AppUser user) async {
    final unsynced = await _databaseService.getUnsyncedExpenses(user.id);

    for (final expense in unsynced) {
      await _trySyncSingleExpense(expense, user);
    }
  }

  bool get _useMongo =>
      AppConfig.mongoUri != null && AppConfig.mongoUri!.trim().isNotEmpty;

  Future<void> _trySyncSingleExpense(Expense expense, AppUser user) async {
    final localId = expense.id;
    if (localId == null) return;

    if (_useMongo) {
      await _trySyncSingleExpenseToMongo(expense, user);
      await _databaseService.markExpenseSynced(localId);
      return;
    }

    try {
      final docRef = _firestore
          .collection('users')
          .doc(user.id)
          .collection('expenses')
          .doc();

      await docRef.set({
        'title': expense.title,
        'amount': expense.amount,
        'category': expense.category,
        'date': expense.date.toIso8601String(),
        'userId': user.id,
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(_syncTimeout);

      await _databaseService.markExpenseSynced(localId, cloudId: docRef.id);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        _cloudSyncDisabledForSession = true;
      }
    } catch (_) {
      // Keep local-first behavior when Firestore is unavailable.
    }
  }

  Future<void> _trySyncSingleExpenseToMongo(
      Expense expense, AppUser user) async {
    try {
      await MongoExpenseRepository.instance
          .upsertExpense(expense.copyWith(userId: user.id, synced: true));
    } catch (_) {
      // Keep local-first behavior when Mongo is unavailable.
    }
  }

  Future<void> _pullCloudExpenses(AppUser user) async {
    if (_useMongo) {
      try {
        final cloudExpenses =
            await MongoExpenseRepository.instance.fetchUserExpenses(user.id);
        await _databaseService.upsertCloudExpenses(cloudExpenses, user.id);
        return;
      } catch (_) {
        // Continue to fallback to Firestore if Mongo fails.
      }
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.id)
          .collection('expenses')
          .orderBy('createdAt', descending: true)
          .limit(200)
          .get()
          .timeout(_syncTimeout);

      final cloudExpenses = snapshot.docs.map((doc) {
        final data = doc.data();
        return Expense(
          title: (data['title'] as String?) ?? '',
          amount: (data['amount'] as num?)?.toInt() ?? 0,
          category: (data['category'] as String?) ?? 'Other',
          date: data['date'] != null
              ? DateTime.tryParse(data['date'] as String) ?? DateTime.now()
              : DateTime.now(),
          userId: user.id,
          synced: true,
        );
      }).toList();

      await _databaseService.upsertCloudExpenses(cloudExpenses, user.id);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        _cloudSyncDisabledForSession = true;
      }
    } catch (_) {
      // Ignore fetch failures and continue with local data.
    }
  }
}
