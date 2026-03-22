import '../models/challenge.dart';
import '../models/expense.dart';
import 'gamification_service.dart';

@Deprecated('Use GamificationService.instance.evaluateChallenges instead. This class is kept for backwards compatibility.')
class ChallengeService {
  ChallengeService._();

  static final ChallengeService instance = ChallengeService._();

  Future<ChallengeEvaluation> evaluateChallenges({
    required List<Expense> expenses,
    required int dailyLimit,
    required int availableBudget,
    required String userId,
    DateTime? now,
    DateTime? cycleStart,
    DateTime? cycleEnd,
  }) async {
    return GamificationService.instance.evaluateChallenges(
      expenses: expenses,
      dailyLimit: dailyLimit,
      availableBudget: availableBudget,
      userId: userId,
      now: now,
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
    );
  }

  Future<void> resetDailyChallenges({required String userId}) async {
    return GamificationService.instance.resetDailyCompletions(userId: userId);
  }
}
