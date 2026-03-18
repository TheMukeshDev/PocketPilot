import 'package:shared_preferences/shared_preferences.dart';

class BudgetCyclePreferences {
  BudgetCyclePreferences._();

  static const String _cycleStartDayPrefix = 'budget_cycle_start_day';

  static String _cycleStartDayKey(String userId) =>
      '${_cycleStartDayPrefix}_$userId';

  static int normalizeDay(int day) => day.clamp(1, 28);

  static int defaultStartDay(DateTime now) => normalizeDay(now.day);

  static Future<int> loadForUser(String userId, {DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_cycleStartDayKey(userId));
    final effective = normalizeDay(raw ?? defaultStartDay(now ?? DateTime.now()));

    if (raw == null) {
      await prefs.setInt(_cycleStartDayKey(userId), effective);
    }

    return effective;
  }

  static Future<void> saveForUser(String userId, int day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_cycleStartDayKey(userId), normalizeDay(day));
  }
}