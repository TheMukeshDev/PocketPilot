import '../models/expense.dart';

class FinancialScoreBreakdown {
  const FinancialScoreBreakdown({
    required this.totalScore,
    required this.budgetDiscipline,
    required this.dailyDiscipline,
    required this.spendingDistribution,
    required this.savingRate,
    required this.status,
    required this.primaryInsight,
    required this.suggestion,
  });

  final int totalScore;
  final int budgetDiscipline;
  final int dailyDiscipline;
  final int spendingDistribution;
  final int savingRate;
  final String status;
  final String primaryInsight;
  final String suggestion;
}

class FinancialScoreService {
  FinancialScoreService._();

  static FinancialScoreBreakdown calculateScore({
    required int monthlyBudget,
    required int rent,
    required int totalSpent,
    required int todaySpent,
    required int dailyLimit,
    required List<Expense> expenses,
    required DateTime cycleStart,
    required DateTime cycleEndExclusive,
  }) {
    final availableBudget = (monthlyBudget - rent).clamp(1, 1000000000);
    final remainingBudget =
        (availableBudget - totalSpent).clamp(-1000000000, availableBudget);
    final cycleLengthDays =
        cycleEndExclusive.difference(cycleStart).inDays.clamp(1, 366);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysElapsed =
        (today.difference(cycleStart).inDays + 1).clamp(1, cycleLengthDays);
    final daysRemaining =
        (cycleEndExclusive.difference(today).inDays).clamp(0, cycleLengthDays);

    final savingsRatio = (remainingBudget / availableBudget).clamp(0.0, 1.0);
    final expectedSpendByNow =
        availableBudget * (daysElapsed / cycleLengthDays);
    final paceRatio =
        expectedSpendByNow <= 0 ? 0.0 : totalSpent / expectedSpendByNow;

    final budgetDisciplineScore = _budgetDisciplineScore(
      paceRatio: paceRatio,
      savingsRatio: savingsRatio,
    );

    final safeDailyLimit = dailyLimit <= 0 ? 1 : dailyLimit;
    final dailyDisciplineScore = todaySpent <= safeDailyLimit
        ? 20
        : (20 - (((todaySpent - safeDailyLimit) / safeDailyLimit) * 20))
            .clamp(0.0, 20.0)
            .round();

    final spendingDistributionScore =
        _spendingDistributionScore(expenses, totalSpent);

    final expectedRemainingRatio =
        (daysRemaining / cycleLengthDays).clamp(0.0, 1.0);
    final savingRateScore = _savingRateScore(
      savingsRatio: savingsRatio,
      expectedRemainingRatio: expectedRemainingRatio,
    );

    final totalScore = (budgetDisciplineScore +
            dailyDisciplineScore +
            spendingDistributionScore +
            savingRateScore)
        .clamp(0, 100);

    final status = _statusLabel(totalScore);
    final insight = _insightText(
      totalScore: totalScore,
      dailyDisciplineScore: dailyDisciplineScore,
      spendingDistributionScore: spendingDistributionScore,
      savingRateScore: savingRateScore,
      todaySpent: todaySpent,
      dailyLimit: dailyLimit,
      expenses: expenses,
      totalSpent: totalSpent,
      availableBudget: availableBudget,
      paceRatio: paceRatio,
    );
    final suggestion = _suggestionText(
      dailyDisciplineScore: dailyDisciplineScore,
      spendingDistributionScore: spendingDistributionScore,
      todaySpent: todaySpent,
      dailyLimit: dailyLimit,
      expenses: expenses,
      paceRatio: paceRatio,
    );

    return FinancialScoreBreakdown(
      totalScore: totalScore,
      budgetDiscipline: budgetDisciplineScore,
      dailyDiscipline: dailyDisciplineScore,
      spendingDistribution: spendingDistributionScore,
      savingRate: savingRateScore,
      status: status,
      primaryInsight: insight,
      suggestion: suggestion,
    );
  }

  static int _budgetDisciplineScore({
    required double paceRatio,
    required double savingsRatio,
  }) {
    if (paceRatio <= 0.85) {
      return 40;
    }
    if (paceRatio <= 1.0) {
      final softReduction = ((paceRatio - 0.85) / 0.15 * 6).round();
      return (40 - softReduction).clamp(0, 40);
    }
    if (paceRatio <= 1.25) {
      final reduction = ((paceRatio - 1.0) / 0.25 * 18).round() + 6;
      return (40 - reduction).clamp(0, 40);
    }

    return (savingsRatio * 18).clamp(0.0, 18.0).round();
  }

  static int _savingRateScore({
    required double savingsRatio,
    required double expectedRemainingRatio,
  }) {
    if (savingsRatio >= expectedRemainingRatio) {
      return 20;
    }

    final delta = (expectedRemainingRatio - savingsRatio).clamp(0.0, 1.0);
    return (20 - (delta * 24)).clamp(0.0, 20.0).round();
  }

  static int _spendingDistributionScore(
      List<Expense> expenses, int totalSpent) {
    if (totalSpent <= 0 || expenses.isEmpty) {
      return 20;
    }

    final totals = <String, int>{};
    for (final expense in expenses) {
      totals[expense.category] =
          (totals[expense.category] ?? 0) + expense.amount;
    }

    final highestCategorySpend =
        totals.values.fold<int>(0, (a, b) => a > b ? a : b);
    final highestShare = highestCategorySpend / totalSpent;

    if (highestShare <= 0.35) {
      return 20;
    }
    if (highestShare <= 0.5) {
      final reduction = ((highestShare - 0.35) / 0.15 * 8).round();
      return (20 - reduction).clamp(0, 20);
    }

    final reduction = ((highestShare - 0.5) / 0.5 * 12).round() + 8;
    return (20 - reduction).clamp(0, 20);
  }

  static String _statusLabel(int score) {
    if (score <= 40) {
      return 'Poor spending control';
    }
    if (score <= 70) {
      return 'Average control';
    }
    if (score <= 90) {
      return 'Good financial habits';
    }
    return 'Excellent budgeting';
  }

  static String _insightText({
    required int totalScore,
    required int dailyDisciplineScore,
    required int spendingDistributionScore,
    required int savingRateScore,
    required int todaySpent,
    required int dailyLimit,
    required List<Expense> expenses,
    required int totalSpent,
    required int availableBudget,
    required double paceRatio,
  }) {
    if (totalScore >= 90) {
      return 'Great job! Your spending behavior is consistently healthy.';
    }

    if (paceRatio > 1.1) {
      return 'Your score dropped because this cycle spending is ahead of the safe pace for your budget.';
    }

    if (dailyDisciplineScore < 12 && dailyLimit > 0) {
      return 'Your score dropped because today\'s spending crossed your daily limit (₹$dailyLimit).';
    }

    if (spendingDistributionScore < 12) {
      final topCategory = _topCategory(expenses);
      return 'Your score dropped because ${topCategory.toLowerCase()} spending is too concentrated.';
    }

    if (savingRateScore < 8) {
      final remaining =
          (availableBudget - totalSpent).clamp(0, availableBudget);
      return 'Your score dropped because only ₹$remaining is left in the current budget cycle.';
    }

    return 'Keep reducing non-essential expenses to push your score higher.';
  }

  static String _suggestionText({
    required int dailyDisciplineScore,
    required int spendingDistributionScore,
    required int todaySpent,
    required int dailyLimit,
    required List<Expense> expenses,
    required double paceRatio,
  }) {
    if (dailyDisciplineScore < 12 && dailyLimit > 0) {
      return 'Try limiting today\'s spending to around ₹$dailyLimit.';
    }

    if (paceRatio > 1.1) {
      return 'Slow down for the next few days and prioritize essentials until spending pace normalizes.';
    }

    if (spendingDistributionScore < 12) {
      final topCategory = _topCategory(expenses);
      return 'Set a weekly cap for $topCategory and move some spend to essentials only.';
    }

    return 'Maintain this rhythm for 7 days to improve your score and unlock more badges.';
  }

  static String _topCategory(List<Expense> expenses) {
    if (expenses.isEmpty) {
      return 'Food';
    }

    final totals = <String, int>{};
    for (final item in expenses) {
      totals[item.category] = (totals[item.category] ?? 0) + item.amount;
    }

    String top = totals.keys.first;
    var max = totals[top] ?? 0;
    totals.forEach((key, value) {
      if (value > max) {
        max = value;
        top = key;
      }
    });
    return top;
  }
}
