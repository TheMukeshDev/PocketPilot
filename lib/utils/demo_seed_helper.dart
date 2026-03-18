import '../models/expense.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class DemoSeedHelper {
  DemoSeedHelper._();

  static Future<void> seedForUser({
    required String userId,
    bool clearExisting = false,
  }) async {
    final store = DatabaseService.instance;
    await store.initDatabase();

    if (clearExisting) {
      final existing = await store.getExpenses(userId);
      for (final expense in existing) {
        final id = expense.id;
        if (id != null) {
          await store.deleteExpense(id);
        }
      }
    }

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final demoExpenses = <Expense>[
      Expense(
        title: 'Hostel Rent',
        amount: 2600,
        category: 'Utilities',
        date: monthStart.add(const Duration(days: 0)),
        userId: userId,
        synced: false,
      ),
      Expense(
        title: 'Supermart Grocery',
        amount: 1450,
        category: 'Food',
        date: monthStart.add(const Duration(days: 1)),
        userId: userId,
        synced: false,
      ),
      Expense(
        title: 'Cab to Office',
        amount: 420,
        category: 'Travel',
        date: monthStart.add(const Duration(days: 1)),
        userId: userId,
        synced: false,
      ),
      Expense(
        title: 'Streaming Subscription',
        amount: 299,
        category: 'Entertainment',
        date: monthStart.add(const Duration(days: 2)),
        userId: userId,
        synced: false,
      ),
      Expense(
        title: 'Restaurant Dinner',
        amount: 780,
        category: 'Food',
        date: monthStart.add(const Duration(days: 3)),
        userId: userId,
        synced: false,
      ),
      Expense(
        title: 'Phone Recharge',
        amount: 399,
        category: 'Recharge',
        date: monthStart.add(const Duration(days: 4)),
        userId: userId,
        synced: false,
      ),
      Expense(
        title: 'Pharmacy',
        amount: 520,
        category: 'Medical',
        date: monthStart.add(const Duration(days: 4)),
        userId: userId,
        synced: false,
      ),
      Expense(
        title: 'Online Shopping',
        amount: 1199,
        category: 'Shopping',
        date: monthStart.add(const Duration(days: 5)),
        userId: userId,
        synced: false,
      ),
      Expense(
        title: 'Coffee + Snacks',
        amount: 260,
        category: 'Food',
        date: monthStart.add(const Duration(days: 6)),
        userId: userId,
        synced: false,
      ),
      Expense(
        title: 'Metro Card Top-up',
        amount: 300,
        category: 'Travel',
        date: monthStart.add(const Duration(days: 7)),
        userId: userId,
        synced: false,
      ),
      Expense(
        title: 'Course Fee Installment',
        amount: 1800,
        category: 'Study',
        date: monthStart.add(const Duration(days: 8)),
        userId: userId,
        synced: false,
      ),
      Expense(
        title: 'Salon',
        amount: 350,
        category: 'Personal',
        date: monthStart.add(const Duration(days: 9)),
        userId: userId,
        synced: false,
      ),
    ];

    for (final expense in demoExpenses) {
      await store.insertExpense(expense);
    }
  }

  static Future<void> seedDefaultDemoAccount({
    bool clearExisting = false,
  }) async {
    await seedForUser(
      userId: 'demo-user',
      clearExisting: clearExisting,
    );
  }

  static Map<String, String> get demoCredentials => {
        'email': AuthService.demoEmail,
        'password': AuthService.demoPassword,
      };
}
