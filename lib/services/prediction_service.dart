class PredictionResult {
  const PredictionResult({
    required this.remainingDays,
    required this.daysInMonth,
    required this.currentDay,
    required this.dailyAverageSpend,
    required this.predictedMonthSpend,
    required this.availableBudget,
    required this.isLikelyToOverspend,
    required this.overspendAmount,
    required this.overspendPercent,
    required this.cutFoodPerDayTip,
    required this.skipOttTip,
  });

  final int remainingDays;
  final int daysInMonth;
  final int currentDay;
  final double dailyAverageSpend;
  final double predictedMonthSpend;
  final int availableBudget;
  final bool isLikelyToOverspend;
  final double overspendAmount;
  final double overspendPercent;
  final int cutFoodPerDayTip;
  final String skipOttTip;

  String get message {
    if (isLikelyToOverspend) {
      return '⚠ You may overspend by ${overspendPercent.toStringAsFixed(1)}% this month.';
    }
    return '✅ Your spending pace looks healthy for this month.';
  }
}

class PredictionService {
  static PredictionResult analyze({
    required int totalSpent,
    required int availableBudget,
    DateTime? now,
  }) {
    final date = now ?? DateTime.now();
    final daysInMonth = DateTime(date.year, date.month + 1, 0).day;
    final currentDay = date.day.clamp(1, daysInMonth);
    final remainingDays = daysInMonth - currentDay;

    final dailyAverageSpend = totalSpent / currentDay;
    final predictedMonthSpend = dailyAverageSpend * daysInMonth;
    final overspendAmount = (predictedMonthSpend - availableBudget)
      .clamp(0.0, double.infinity)
      .toDouble();
    final overspendPercent = availableBudget <= 0
      ? (predictedMonthSpend > 0 ? 100.0 : 0.0)
        : (overspendAmount / availableBudget) * 100;
    final targetDays = remainingDays > 0 ? remainingDays : 1;
    final cutFoodPerDayTip = (overspendAmount / targetDays).ceil();
    const skipOttTip =
        'Skip one OTT renewal this month (₹149–₹299) to reduce non-essential spend.';

    return PredictionResult(
      remainingDays: remainingDays,
      daysInMonth: daysInMonth,
      currentDay: currentDay,
      dailyAverageSpend: dailyAverageSpend,
      predictedMonthSpend: predictedMonthSpend,
      availableBudget: availableBudget,
      isLikelyToOverspend: predictedMonthSpend > availableBudget,
      overspendAmount: overspendAmount,
      overspendPercent: overspendPercent,
      cutFoodPerDayTip: cutFoodPerDayTip,
      skipOttTip: skipOttTip,
    );
  }
}