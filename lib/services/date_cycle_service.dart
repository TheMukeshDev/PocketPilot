import 'package:intl/intl.dart';

/// Utility service for handling budget cycle date calculations
class DateCycleService {
  DateCycleService._();

  static final DateCycleService instance = DateCycleService._();

  /// Get the start date of the current budget cycle
  DateTime getCycleStart(DateTime selectedDate) {
    return DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  }

  /// Get the end date of the current budget cycle
  /// Logic: Start date inclusive, end date = next month same date - 1 day
  DateTime getCycleEnd(DateTime cycleStart) {
    // Calculate next month same date
    DateTime nextMonthSameDate = DateTime(
      cycleStart.year,
      cycleStart.month + 1,
      cycleStart.day,
    );

    // Handle month edge cases (28, 30, 31 days) and leap year
    // If next month doesn't have the same date, adjust to last day of month
    if (nextMonthSameDate.month != cycleStart.month + 1 ||
        nextMonthSameDate.day != cycleStart.day) {
      // Invalid date (e.g., Feb 30), adjust to last day of the target month
      int targetMonth = cycleStart.month + 1;
      int targetYear = cycleStart.year;
      if (targetMonth > 12) {
        targetMonth = 1;
        targetYear += 1;
      }
      nextMonthSameDate =
          DateTime(targetYear, targetMonth + 1, 0); // Last day of target month
    }

    // End date = next month same date - 1 day
    return nextMonthSameDate.subtract(const Duration(days: 1));
  }

  /// Check if a given date falls within the specified cycle
  bool isDateInCycle(DateTime date, DateTime cycleStart, DateTime cycleEnd) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedStart =
        DateTime(cycleStart.year, cycleStart.month, cycleStart.day);
    final normalizedEnd = DateTime(cycleEnd.year, cycleEnd.month, cycleEnd.day);

    return !normalizedDate.isBefore(normalizedStart) &&
        !normalizedDate.isAfter(normalizedEnd);
  }

  /// Get the total number of days in the cycle
  int getDaysInCycle(DateTime cycleStart, DateTime cycleEnd) {
    return cycleEnd.difference(cycleStart).inDays + 1; // +1 because inclusive
  }

  /// Get a human-readable date string
  String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date); // e.g., "21 Feb 2026"
  }

  /// Get relative date options for the date picker
  List<DateTime> getQuickDateOptions() {
    final now = DateTime.now();
    return [
      DateTime(now.year, now.month, now.day), // Today
      DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 1)), // Yesterday
      DateTime(now.year, now.month, now.day)
          .add(const Duration(days: 1)), // Tomorrow
    ];
  }

  /// Get display labels for quick date options
  List<String> getQuickDateLabels() {
    return ['Today', 'Yesterday', 'Tomorrow'];
  }
}
