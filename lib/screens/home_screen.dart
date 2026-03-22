import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';

import '../models/expense.dart';
import '../models/challenge.dart';
import '../services/app_config.dart';
import '../services/budget_cycle_preferences.dart';
import '../services/date_cycle_service.dart';
import '../services/auth_service.dart';
import '../services/gamification_service.dart';
import '../services/database_service.dart';
import '../services/expense_service.dart';
import '../services/financial_score_service.dart';
import '../services/notification_service.dart';
import '../services/notification_trigger_service.dart';
import '../services/prediction_service.dart';
import '../services/report_service.dart';
import '../services/sms_expense_parser.dart';
import '../services/sms_tracking_preferences.dart';
import '../services/theme_service.dart';
import '../widgets/alert_card.dart';
import '../widgets/budget_card.dart';
import '../widgets/challenge_card.dart';
import '../widgets/financial_health_card.dart';
import '../widgets/points_history_card.dart';
import '../widgets/main_bottom_nav.dart';
import '../widgets/prediction_card.dart';
import '../widgets/sms_expense_dialog.dart';
import '../widgets/spending_chart.dart';
import 'add_expense_screen.dart';
import 'about_app_screen.dart';
import 'alerts_screen.dart';
import 'challenge_screen.dart';
import 'monthly_report_screen.dart';
import 'payment_history_screen.dart';
import 'scan_receipt_screen.dart';
import 'scan_qr_payment_screen.dart';
import 'settings_screen.dart';
import 'weekly_trends_screen.dart';

/// Top-level background SMS handler required by the telephony package.
/// Runs in a separate Dart isolate — Flutter UI cannot be updated here.
@pragma('vm:entry-point')
void onBackgroundSmsReceived(SmsMessage message) {
  // No-op for hackathon build: foreground detection in HomeScreen covers
  // the full demo flow. A production app would enqueue the parsed expense
  // in SharedPreferences for surfacing on next app open.
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.expenseStore,
    this.userId,
    this.displayName,
  });

  final ExpenseStore? expenseStore;
  final String? userId;
  final String? displayName;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _defaultMonthlyBudget = 5000;
  static const int _defaultRent = 2700;
  static const bool _seedSampleExpensesOnStart = false;
  static const Duration _manualSyncTimeout = Duration(seconds: 12);
  int _monthlyBudget = _defaultMonthlyBudget;
  int _rent = _defaultRent;
  int _budgetCycleStartDay = 1;

  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isOnline = true;
  List<Expense> expenses = [];
  List<Challenge> _activeChallenges = const <Challenge>[];
  GamificationStats _gamificationStats = GamificationStats.empty;
  String? _recentlyCompletedChallengeId;
  List<PointsHistoryEntry> _pointsHistory = [];

  // ── SMS auto-detection state ─────────────────────────────────────────────
  final Telephony _telephony = Telephony.instance;
  int _smsDetectedCount = 0;
  int _smsTotalAmount = 0;
  SmsApprovalMode _smsApprovalMode = SmsApprovalMode.askEveryTime;
  static const Duration _duplicateDetectionWindow = Duration(minutes: 3);
  final List<_PaymentMarker> _recentInAppPayments = <_PaymentMarker>[];

  late final Connectivity _connectivity;
  late final ExpenseStore _expenseStore;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  final Set<String> _shownAlerts = <String>{};

  @override
  void initState() {
    super.initState();
    _connectivity = Connectivity();
    _expenseStore = widget.expenseStore ?? DatabaseService.instance;
    _setupConnectivityListener();
    _initializeData();
    // Safety net: if DB takes too long or throws uncaught, clear spinner.
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });
    // Request permission safely after the UI is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.requestPermissionAndSchedule();
      _initSmsListener();
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    // Load local data first — UI is unblocked immediately.
    if (widget.expenseStore == null) {
      await _expenseStore.initDatabase();
    }
    await _loadBudgetAndRent();
    await _loadSmsApprovalMode();
    await _loadLocalExpenses();
    await _refreshChallenges();
    if (_seedSampleExpensesOnStart && expenses.isEmpty) {
      await _addSampleExpensesForTesting();
    }
    // Connectivity check + cloud sync run in background.
    _updateConnectivityStatus();
    _backgroundSync();
  }

  DateTime get _currentCycleStart {
    final now = DateTime.now();
    final dateService = DateCycleService.instance;
    final startDate = DateTime(now.year, now.month, _budgetCycleStartDay);
    return dateService.getCycleStart(startDate);
  }

  DateTime get _currentCycleEnd {
    final dateService = DateCycleService.instance;
    return dateService.getCycleEnd(_currentCycleStart);
  }

  List<Expense> get _currentCycleExpenses {
    return expenses.where((expense) {
      return !expense.date.isBefore(_currentCycleStart) &&
          expense.date.isBefore(_currentCycleEnd);
    }).toList();
  }

  int get totalSpent =>
      _currentCycleExpenses.fold(0, (sum, item) => sum + item.amount);

  int get availableBudget => _monthlyBudget - _rent;

  int get remaining => availableBudget - totalSpent;

  int get dailySpendingLimit {
    final todayStart = DateTime.now();
    final today = DateTime(todayStart.year, todayStart.month, todayStart.day);
    final daysRemaining = _currentCycleEnd.difference(today).inDays;
    if (remaining <= 0) {
      return 0;
    }
    if (daysRemaining <= 0) {
      return remaining;
    }

    final limit = (remaining / daysRemaining).floor();
    return limit > 0 ? limit : 1;
  }

  int get todaySpent {
    final now = DateTime.now();
    return expenses
        .where(
          (expense) =>
              expense.date.year == now.year &&
              expense.date.month == now.month &&
              expense.date.day == now.day,
        )
        .fold(0, (sum, item) => sum + item.amount);
  }

  PredictionResult get _prediction => PredictionService.analyze(
        totalSpent: totalSpent,
        availableBudget: availableBudget,
        cycleStart: _currentCycleStart,
        cycleEnd: _currentCycleEnd,
      );

  FinancialScoreBreakdown get _financialHealthScore =>
      FinancialScoreService.calculateScore(
        monthlyBudget: _monthlyBudget,
        rent: _rent,
        totalSpent: totalSpent,
        todaySpent: todaySpent,
        dailyLimit: dailySpendingLimit,
        expenses: _currentCycleExpenses,
        cycleStart: _currentCycleStart,
        cycleEndExclusive: _currentCycleEnd,
      );

  List<String> get _alertMessages {
    final alerts = <String>[];

    if (todaySpent > dailySpendingLimit) {
      alerts.add('⚠ You exceeded today\'s spending limit.');
    }

    if (availableBudget > 0 && (remaining / availableBudget) <= 0.2) {
      alerts.add('⚠ Only 20% of your budget is left.');
    }

    if (_prediction.isLikelyToOverspend) {
      alerts.add('⚠ You are likely to overspend this month.');
    }

    return alerts;
  }

  /// Loads only local DB data — instant, never waits on network.
  Future<void> _loadLocalExpenses() async {
    try {
      final currentUser = AuthService.instance.currentUser;
      final effectiveUserId = widget.userId ?? currentUser?.id;
      final loadedExpenses = await _expenseStore.getExpenses(effectiveUserId);

      if (!mounted) {
        return;
      }

      setState(() {
        expenses = loadedExpenses;
      });

      await _refreshChallenges();

      _showRealtimeAlerts();
    } catch (_) {
      // DB error — show empty list rather than infinite spinner.
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Syncs with cloud in background and refreshes list when done.
  Future<void> _backgroundSync() async {
    if (widget.expenseStore != null) {
      return;
    }

    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      return;
    }

    try {
      await ExpenseService.instance.syncNow(currentUser);

      final updated =
          await ExpenseService.instance.getExpensesForUser(currentUser);

      if (!mounted) {
        return;
      }

      setState(() {
        expenses = updated;
      });

      _showRealtimeAlerts();
    } catch (_) {
      // Silent — local data already displayed.
    }
  }

  Future<void> _loadExpenses() async {
    await _loadLocalExpenses();
    _backgroundSync();
  }

  Future<void> _refreshData() async {
    await _loadExpenses();
    await _refreshChallenges();
  }

  String _budgetPreferenceKey(String userId) => 'monthly_budget_$userId';
  String _rentPreferenceKey(String userId) => 'monthly_rent_$userId';

  Future<void> _loadBudgetAndRent() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = AuthService.instance.currentUser?.id ?? 'guest';
    final savedBudget = prefs.getInt(_budgetPreferenceKey(userId));
    final savedRent = prefs.getInt(_rentPreferenceKey(userId));
    final cycleStartDay = await BudgetCyclePreferences.loadForUser(userId);

    if (!mounted) {
      return;
    }

    setState(() {
      _monthlyBudget = savedBudget ?? _defaultMonthlyBudget;
      _rent = savedRent ?? _defaultRent;
      _budgetCycleStartDay = cycleStartDay;
    });
  }

  Future<void> _loadSmsApprovalMode() async {
    final userId = AuthService.instance.currentUser?.id ?? 'guest';
    final mode = await SmsTrackingPreferences.loadForUser(userId);
    if (!mounted) {
      return;
    }
    setState(() {
      _smsApprovalMode = mode;
    });
  }

  Future<void> _addExpense(Expense expense) async {
    final currentUser = AuthService.instance.currentUser;
    final effectiveUserId = widget.userId ?? currentUser?.id;
    final localExpense = expense.copyWith(
      userId: effectiveUserId,
      synced: false,
    );

    final savedExpense = await _expenseStore.insertExpense(localExpense);

    if (!mounted) {
      return;
    }

    setState(() {
      expenses = [savedExpense, ...expenses];
    });

    await _refreshChallenges();
    await _showChallengeCompletionDialog();

    _showRealtimeAlerts();

    if (widget.expenseStore == null && currentUser != null) {
      unawaited(_syncExpenses());
    }
  }

  Future<void> _addSampleExpensesForTesting() async {
    final now = DateTime.now();
    await _addExpense(
      Expense(
        title: 'Tea',
        amount: 20,
        category: 'Food',
        date: now,
      ),
    );
    await _addExpense(
      Expense(
        title: 'Bus Fare',
        amount: 35,
        category: 'Travel',
        date: now,
      ),
    );
    await _addExpense(
      Expense(
        title: 'Notebook',
        amount: 80,
        category: 'Study',
        date: now,
      ),
    );
  }

  Future<void> _openManualAddExpenseScreen() async {
    final newExpense = await Navigator.of(context).push<Expense>(
      MaterialPageRoute(
        builder: (context) => const AddExpenseScreen(),
      ),
    );

    if (newExpense != null) {
      await _addExpense(newExpense);
    }
  }

  Future<void> _openScanReceiptScreen() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.document_scanner_rounded),
                title: const Text('Add Receipt'),
                subtitle: const Text('Use camera/gallery auto-detection'),
                onTap: () => Navigator.of(sheetContext).pop('scan'),
              ),
              ListTile(
                leading: const Icon(Icons.edit_note_rounded),
                title: const Text('Add Manually'),
                subtitle:
                    const Text('Enter title, amount and category yourself'),
                onTap: () => Navigator.of(sheetContext).pop('manual'),
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == 'manual') {
      await _openManualAddExpenseScreen();
      return;
    }

    final newExpense = await Navigator.of(context).push<Expense>(
      MaterialPageRoute(
        builder: (context) => const ScanReceiptScreen(),
      ),
    );

    if (newExpense != null) {
      await _addExpense(newExpense);
    }
  }

  Future<void> _openPayExpense() async {
    final paidExpense = await Navigator.of(context).push<Expense>(
      MaterialPageRoute(
        builder: (_) => const ScanQrPaymentScreen(),
      ),
    );

    if (paidExpense != null) {
      _registerInAppPayment(paidExpense);
      await _addExpense(paidExpense);
    }
  }

  void _registerInAppPayment(Expense expense) {
    final title = expense.title.toLowerCase();
    final isOnlinePayment = title.contains('[online]') || title.contains('upi');
    if (!isOnlinePayment) {
      return;
    }

    final now = DateTime.now();
    _recentInAppPayments.removeWhere(
      (marker) => now.difference(marker.createdAt) > _duplicateDetectionWindow,
    );
    _recentInAppPayments.add(
      _PaymentMarker(
        amount: expense.amount,
        createdAt: now,
      ),
    );
  }

  void _openPaymentHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentHistoryScreen(expenses: expenses),
      ),
    );
  }

  void _openAlertsAndMotivation() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlertsScreen(alertMessages: _alertMessages),
      ),
    );
  }

  void _openMonthlyReport() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MonthlyReportScreen(
          expenses: expenses,
          monthlyBudget: _monthlyBudget,
          rent: _rent,
          cycleStart: _currentCycleStart,
          cycleEnd: _currentCycleEnd,
        ),
      ),
    );
  }

  void _openWeeklyTrends() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WeeklyTrendsScreen(expenses: expenses),
      ),
    );
  }

  Future<void> _exportPdfReport() async {
    try {
      await ReportService.instance.exportSpendingReportPdf(
        expenses: expenses,
        monthlyBudget: _monthlyBudget,
        rent: _rent,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spending report ready to share.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to export PDF report.')),
      );
    }
  }

  Future<void> _toggleTheme() async {
    await ThemeService.instance.toggleBetweenLightAndDark();
  }

  Future<void> _setupConnectivityListener() async {
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((result) async {
      final nowOnline = result != ConnectivityResult.none;
      if (!mounted) {
        return;
      }

      final wasOnline = _isOnline;
      setState(() => _isOnline = nowOnline);

      if (!wasOnline && nowOnline) {
        await _syncExpenses();
        await NotificationService.instance.showSyncRestoredNotification();
      }
    });
  }

  Future<void> _updateConnectivityStatus() async {
    final result = await _connectivity.checkConnectivity();
    if (!mounted) {
      return;
    }
    setState(() => _isOnline = result != ConnectivityResult.none);
  }

  Future<void> _syncExpenses() async {
    if (_isSyncing) {
      return;
    }

    if (widget.expenseStore != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Offline mode active. Data is stored locally.')),
        );
      }
      return;
    }

    if (!_isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No internet. Working in offline mode.')),
        );
      }
      return;
    }

    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      return;
    }

    setState(() => _isSyncing = true);
    try {
      await ExpenseService.instance
          .syncNow(currentUser)
          .timeout(_manualSyncTimeout);
      await _loadLocalExpenses();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync completed successfully.')),
      );
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Sync timed out. Offline mode continues with local data.'),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync failed. Will retry automatically.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _fetchFromCloud() async {
    if (_isSyncing) {
      return;
    }

    if (!_isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No internet. Showing local data only.')),
        );
      }
      return;
    }

    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      return;
    }

    setState(() => _isSyncing = true);
    try {
      await ExpenseService.instance.syncAndFetch(currentUser);
      await _loadLocalExpenses();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Latest cloud data fetched successfully.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Unable to fetch cloud data now. Showing local snapshot.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _refreshChallenges() async {
    final currentUser = AuthService.instance.currentUser;
    final effectiveUserId = widget.userId ?? currentUser?.id ?? 'guest';

    NotificationTriggerService.instance.updatePreviousStreak(
      _gamificationStats.currentStreak,
    );

    final evaluation = await GamificationService.instance.evaluateChallenges(
      expenses: _currentCycleExpenses,
      dailyLimit: dailySpendingLimit,
      availableBudget: availableBudget,
      userId: effectiveUserId,
      cycleStart: _currentCycleStart,
      cycleEnd: _currentCycleEnd,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _activeChallenges = evaluation.challenges;
      _gamificationStats = evaluation.stats;
      _recentlyCompletedChallengeId = evaluation.newlyCompleted.isEmpty
          ? null
          : evaluation.newlyCompleted.first.challenge.id;
    });

    await NotificationTriggerService.instance.checkAndTriggerNotifications(
      expenses: expenses,
      dailyLimit: dailySpendingLimit,
      monthlyBudget: _monthlyBudget,
      rent: _rent,
      gamificationStats: _gamificationStats,
      challenges: _activeChallenges,
      cycleStart: _currentCycleStart,
      cycleEnd: _currentCycleEnd,
      isManualRefresh: true,
    );

    for (final badge in evaluation.newlyUnlockedBadges) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🏅 Badge unlocked: $badge')),
      );
    }

    await _loadPointsHistory();
  }

  Future<void> _loadPointsHistory() async {
    final currentUser = AuthService.instance.currentUser;
    final userId = widget.userId ?? currentUser?.id ?? 'guest';
    
    final history = await GamificationService.instance.getPointsHistory(userId);
    
    if (!mounted) return;
    
    setState(() {
      _pointsHistory = history;
    });
  }

  void _openPointsHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PointsHistoryFullScreen(history: _pointsHistory),
      ),
    );
  }

  Future<void> _showChallengeCompletionDialog() async {
    if (_recentlyCompletedChallengeId == null || !mounted) {
      return;
    }

    final challenge = _activeChallenges.firstWhere(
      (item) => item.id == _recentlyCompletedChallengeId,
      orElse: () => const Challenge(
        id: '',
        title: '',
        description: '',
        targetAmount: 0,
        rewardPoints: 0,
        progress: 0,
        isCompleted: false,
        challengeType: ChallengeType.daily,
      ),
    );

    if (challenge.id.isEmpty) {
      return;
    }

    final savedAmount = challenge.challengeType == ChallengeType.daily
        ? (challenge.targetAmount - todaySpent).clamp(0, challenge.targetAmount)
        : challenge.challengeType == ChallengeType.weekly
            ? challenge.targetAmount
            : _gamificationStats.currentStreak;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('🎉 Challenge Completed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(challenge.title),
              const SizedBox(height: 10),
              Text('You saved ₹$savedAmount today'),
              const SizedBox(height: 4),
              Text(
                '+${challenge.rewardPoints} Points Earned',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(dialogContext).colorScheme.primary,
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Awesome!'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _recentlyCompletedChallengeId = null;
    });
  }

  void _openChallengeDashboard() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChallengeScreen(
          stats: _gamificationStats,
          challenges: _activeChallenges,
          cycleStartDay: _budgetCycleStartDay,
          highlightChallengeId: _recentlyCompletedChallengeId,
        ),
      ),
    );
  }

  void _showRealtimeAlerts() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final messages = _alertMessages;
      for (final message in messages) {
        if (_shownAlerts.contains(message)) {
          continue;
        }
        _shownAlerts.add(message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });
  }

  // ── SMS Auto-Detection ───────────────────────────────────────────────────

  /// Requests SMS permission (Android only) and starts the incoming-SMS listener.
  Future<void> _initSmsListener() async {
    if (!AppConfig.enableSmsAutoTrack || !Platform.isAndroid) {
      return;
    }

    final granted = await _telephony.requestPhoneAndSmsPermissions ?? false;
    if (!granted || !mounted) return;

    _telephony.listenIncomingSms(
      onNewMessage: _handleIncomingSms,
      onBackgroundMessage: onBackgroundSmsReceived,
    );
  }

  void _handleIncomingSms(SmsMessage message) {
    final body = message.body;
    if (body == null || body.isEmpty) return;

    final detected = SmsExpenseParser.parse(body);
    if (detected == null) return;

    // Process after the current frame so UI interactions are safe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_handleDetectedSmsExpense(detected));
    });
  }

  Future<void> _handleDetectedSmsExpense(SmsExpenseData data) async {
    if (!mounted) {
      return;
    }

    if (_isDuplicateAgainstRecentInAppPayment(data.amount)) {
      return;
    }

    switch (_smsApprovalMode) {
      case SmsApprovalMode.askEveryTime:
        await _showSmsExpenseDialog(data);
        return;
      case SmsApprovalMode.alwaysApprove:
        await _saveDetectedSmsExpense(
          _buildExpenseFromDetectedSms(data),
          messagePrefix: '✅ Auto-approved',
        );
        return;
      case SmsApprovalMode.alwaysAddDirectly:
        await _saveDetectedSmsExpense(
          _buildExpenseFromDetectedSms(data),
          messagePrefix: '⚡ Added directly',
        );
        return;
    }
  }

  Expense _buildExpenseFromDetectedSms(SmsExpenseData data) {
    final normalizedTitle =
        data.title.trim().isEmpty ? 'Auto Detected' : data.title.trim();

    return Expense(
      title: '[Online SMS] $normalizedTitle',
      amount: data.amount,
      category: data.category,
      date: DateTime.now(),
    );
  }

  Future<void> _saveDetectedSmsExpense(
    Expense expense, {
    required String messagePrefix,
  }) async {
    if (_isDuplicateExpense(expense)) {
      return;
    }

    await _addExpense(expense);
    if (!mounted) {
      return;
    }
    setState(() {
      _smsDetectedCount++;
      _smsTotalAmount += expense.amount;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$messagePrefix: ${expense.title} ₹${expense.amount}'),
      ),
    );
  }

  bool _isDuplicateAgainstRecentInAppPayment(int amount) {
    final now = DateTime.now();
    _recentInAppPayments.removeWhere(
      (marker) => now.difference(marker.createdAt) > _duplicateDetectionWindow,
    );

    return _recentInAppPayments.any((marker) => marker.amount == amount);
  }

  bool _isDuplicateExpense(Expense candidate) {
    final now = DateTime.now();
    return expenses.any((existing) {
      final sameAmount = existing.amount == candidate.amount;
      final closeInTime =
          now.difference(existing.date).abs() <= _duplicateDetectionWindow;
      final existingTitle = existing.title.toLowerCase();
      final candidateTitle = candidate.title.toLowerCase();
      final sameSource = existingTitle == candidateTitle ||
          (existingTitle.contains('[online]') &&
              candidateTitle.contains('[online]'));
      return sameAmount && closeInTime && sameSource;
    });
  }

  Future<void> _showSmsExpenseDialog(SmsExpenseData data) async {
    if (!mounted) return;

    final expense = await showDialog<Expense>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SmsExpenseDialog(data: data),
    );

    if (expense != null) {
      await _saveDetectedSmsExpense(
        expense,
        messagePrefix: '📱 Auto-tracked',
      );
    }
  }

  void _openHowItWorks() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _HowItWorksSheet(),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          monthlyBudget: _monthlyBudget,
          rent: _rent,
          budgetCycleStartDay: _budgetCycleStartDay,
          smsApprovalMode: _smsApprovalMode,
          onBudgetUpdated: (v) => setState(() => _monthlyBudget = v),
          onRentUpdated: (v) => setState(() => _rent = v),
          onBudgetCycleStartDayUpdated: (day) {
            setState(() {
              _budgetCycleStartDay = day;
            });
            unawaited(_refreshChallenges());
          },
          onSmsApprovalModeUpdated: (mode) {
            setState(() {
              _smsApprovalMode = mode;
            });
          },
        ),
      ),
    );
  }

  void _openAboutApp() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AboutAppScreen()),
    );
  }

  void _handleAppBarAction(String value) {
    switch (value) {
      case 'how_it_works':
        _openHowItWorks();
        break;
      case 'settings':
        _openSettings();
        break;
      case 'about':
        _openAboutApp();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = AuthService.instance.currentUser;
    final greetingName = widget.displayName?.trim().isNotEmpty == true
        ? widget.displayName!.trim()
        : currentUser?.displayName?.trim().isNotEmpty == true
            ? currentUser!.displayName!.trim()
            : currentUser?.email.split('@').first ?? 'there';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final themeToggleLabel =
        isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode';
    final themeToggleIcon =
        isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PocketPilot'),
        actions: [
          // Theme toggle — always visible in AppBar
          IconButton(
            onPressed: _toggleTheme,
            icon: Icon(themeToggleIcon),
            tooltip: themeToggleLabel,
          ),
          // Download and sync - combined action
          IconButton(
            onPressed: _isSyncing ? null : () async {
              await _fetchFromCloud();
              await _syncExpenses();
            },
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            tooltip: 'Download & Sync',
          ),
          // Three-dot menu
          PopupMenuButton<String>(
            onSelected: _handleAppBarAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'how_it_works',
                child: Row(
                  children: [
                    Icon(Icons.help_outline_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('How It Works'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('About App'),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'More',
          ),
        ],
      ),
      bottomNavigationBar: MainBottomNav(
        currentTab: AppBottomTab.home,
        onHomeTap: () {},
        onAlertsTap: _openAlertsAndMotivation,
        onPayTap: _openPayExpense,
        onAddReceiptTap: _openScanReceiptScreen,
        onHistoryTap: _openPaymentHistory,
        alertsCount: _alertMessages.length,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.only(bottom: 128),
                    children: [
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: colorScheme.primaryContainer,
                                child: Icon(
                                  Icons.person_rounded,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hi $greetingName 👋',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Track smart, spend smarter.',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              _StatusChip(
                                isOnline: _isOnline,
                                isSyncing: _isSyncing,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _QuickActionsGrid(
                        onMonthlyReport: _openMonthlyReport,
                        onWeeklyTrends: _openWeeklyTrends,
                        onScanReceipt: _openScanReceiptScreen,
                        onPayExpense: _openPayExpense,
                        onExportPdf: _exportPdfReport,
                        onChallenges: _openChallengeDashboard,
                      ),
                      const SizedBox(height: 4),
                      if (_smsDetectedCount > 0)
                        _SmsAutoTrackBanner(
                          detectedCount: _smsDetectedCount,
                          totalAmount: _smsTotalAmount,
                        ),
                      FinancialHealthCard(
                        breakdown: _financialHealthScore,
                      ),
                      const SizedBox(height: 8),
                      if (_activeChallenges.isNotEmpty) ...[
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.emoji_events_rounded,
                                          color: Theme.of(context).colorScheme.primary,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Savings Challenges',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primaryContainer,
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            '${_gamificationStats.totalPoints} pts',
                                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.tertiaryContainer,
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.local_fire_department_rounded,
                                                color: Theme.of(context).colorScheme.tertiary,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${_gamificationStats.currentStreak}',
                                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ..._activeChallenges.map(
                                  (challenge) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: ChallengeCard(
                                      challenge: challenge,
                                      highlightCompletion: _recentlyCompletedChallengeId ==
                                          challenge.id,
                                      onTap: _openChallengeDashboard,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _ChallengeProgressChip(
                                      type: ChallengeType.daily,
                                      challenge: _activeChallenges.firstWhere(
                                        (c) => c.challengeType == ChallengeType.daily,
                                        orElse: () => _activeChallenges.first,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _ChallengeProgressChip(
                                      type: ChallengeType.weekly,
                                      challenge: _activeChallenges.firstWhere(
                                        (c) => c.challengeType == ChallengeType.weekly,
                                        orElse: () => _activeChallenges.first,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _ChallengeProgressChip(
                                      type: ChallengeType.streak,
                                      challenge: _activeChallenges.firstWhere(
                                        (c) => c.challengeType == ChallengeType.streak,
                                        orElse: () => _activeChallenges.first,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _openChallengeDashboard,
                                        icon: const Icon(Icons.leaderboard_rounded, size: 18),
                                        label: const Text('View History'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: _openPointsHistory,
                                        icon: const Icon(Icons.history_rounded, size: 18),
                                        label: const Text('Points Log'),
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      ..._alertMessages.map(
                        (message) => AlertCard(message: message),
                      ),
                      BudgetCard(
                        title: 'Monthly Budget',
                        value: '₹$_monthlyBudget',
                        icon: Icons.account_balance_wallet_rounded,
                      ),
                      BudgetCard(
                        title: 'Fixed Rent',
                        value: '₹$_rent',
                        icon: Icons.home_work_rounded,
                      ),
                      BudgetCard(
                        title: 'Total Spent',
                        value: '₹$totalSpent',
                        icon: Icons.payments_rounded,
                        backgroundColor: colorScheme.surfaceVariant,
                      ),
                      BudgetCard(
                        title: 'Today Spend',
                        value: '₹$todaySpent',
                        icon: Icons.today_rounded,
                        backgroundColor: todaySpent > dailySpendingLimit &&
                                dailySpendingLimit > 0
                            ? colorScheme.errorContainer
                            : colorScheme.primaryContainer,
                        valueColor: todaySpent > dailySpendingLimit &&
                                dailySpendingLimit > 0
                            ? colorScheme.onErrorContainer
                            : colorScheme.onPrimaryContainer,
                      ),
                      BudgetCard(
                        title: 'Left to Spend',
                        value: '₹$remaining',
                        icon: Icons.savings_rounded,
                        valueColor: remaining < 0
                            ? colorScheme.error
                            : colorScheme.primary,
                      ),
                      BudgetCard(
                        title: 'Daily Safe Limit',
                        value: '₹$dailySpendingLimit',
                        icon: Icons.calendar_today_rounded,
                        backgroundColor: colorScheme.secondaryContainer,
                        emphasize: true,
                      ),
                      PredictionCard(prediction: _prediction),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Spending Analytics',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              SpendingChart(expenses: expenses),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Expenses',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          TextButton(
                            onPressed: _openPaymentHistory,
                            child: const Text('See All'),
                          ),
                        ],
                      ),
                      if (expenses.isEmpty)
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.inbox_rounded, size: 36, color: colorScheme.outlineVariant),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No expenses yet',
                                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        ...List.generate(
                          expenses.length > 5 ? 5 : expenses.length,
                          (index) {
                            final expense = expenses[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _ExpenseListItem(
                                expense: expense,
                                onEdit: () => _editExpense(expense),
                                onDelete: () => _confirmDeleteExpense(expense),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Delete "${expense.title}" (₹${expense.amount})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteExpense(expense);
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    final id = expense.id;
    if (id != null) {
      await _expenseStore.deleteExpense(id);
    }

    if (!mounted) return;

    setState(() {
      expenses = expenses.where((item) => item.id != expense.id).toList();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expense deleted')),
    );
  }

  Future<void> _editExpense(Expense expense) async {
    final updated = await Navigator.of(context).push<Expense>(
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(expenseToEdit: expense),
      ),
    );

    if (updated == null || !mounted) return;

    await ExpenseService.instance.updateExpense(updated);

    setState(() {
      final index = expenses.indexWhere((e) => e.id == expense.id);
      if (index != -1) {
        expenses[index] = updated;
      }
      expenses.sort((a, b) => b.date.compareTo(a.date));
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expense updated')),
    );
  }
}

class _PaymentMarker {
  const _PaymentMarker({
    required this.amount,
    required this.createdAt,
  });

  final int amount;
  final DateTime createdAt;
}

class _ExpenseListItem extends StatelessWidget {
  const _ExpenseListItem({
    required this.expense,
    required this.onEdit,
    required this.onDelete,
  });

  final Expense expense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                _getCategoryIcon(expense.category),
                color: colorScheme.onPrimaryContainer,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    expense.category,
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Text(
              '₹${expense.amount}',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.edit_rounded, size: 20, color: colorScheme.primary),
              onPressed: onEdit,
              tooltip: 'Edit',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: Icon(Icons.delete_rounded, size: 20, color: colorScheme.error),
              onPressed: onDelete,
              tooltip: 'Delete',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food': return Icons.restaurant_rounded;
      case 'travel': return Icons.directions_car_rounded;
      case 'shopping': return Icons.shopping_bag_rounded;
      case 'entertainment': return Icons.movie_rounded;
      case 'bills': return Icons.receipt_rounded;
      case 'health': return Icons.medical_services_rounded;
      case 'education': return Icons.school_rounded;
      case 'savings': return Icons.savings_rounded;
      default: return Icons.payment_rounded;
    }
  }
}

// ── Quick Actions Grid (PhonePe-style) ───────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    required this.onMonthlyReport,
    required this.onWeeklyTrends,
    required this.onScanReceipt,
    required this.onPayExpense,
    required this.onExportPdf,
    required this.onChallenges,
  });

  final VoidCallback onMonthlyReport;
  final VoidCallback onWeeklyTrends;
  final VoidCallback onScanReceipt;
  final VoidCallback onPayExpense;
  final VoidCallback onExportPdf;
  final VoidCallback onChallenges;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final actions = [
      _QuickAction(
        icon: Icons.assessment_rounded,
        label: 'Monthly\nReport',
        color: colorScheme.secondary,
        onTap: onMonthlyReport,
      ),
      _QuickAction(
        icon: Icons.show_chart_rounded,
        label: 'Weekly\nTrends',
        color: colorScheme.tertiary,
        onTap: onWeeklyTrends,
      ),
      _QuickAction(
        icon: Icons.document_scanner_rounded,
        label: 'Add\nReceipt',
        color: colorScheme.error,
        onTap: onScanReceipt,
      ),
      _QuickAction(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Pay\nExpense',
        color: colorScheme.primary,
        onTap: onPayExpense,
      ),
      _QuickAction(
        icon: Icons.picture_as_pdf_rounded,
        label: 'Export\nPDF',
        color: colorScheme.secondary,
        onTap: onExportPdf,
      ),
      _QuickAction(
        icon: Icons.emoji_events_rounded,
        label: 'Challenges',
        color: colorScheme.tertiary,
        onTap: onChallenges,
      ),
    ];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 4,
          childAspectRatio: 1.0,
          children: actions
              .map((action) => _QuickActionTile(action: action))
              .toList(),
        ),
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});
  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: action.color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(action.icon, color: action.color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            action.label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Status Chip ──────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.isOnline,
    required this.isSyncing,
  });

  final bool isOnline;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final text = isSyncing
        ? 'Syncing'
        : isOnline
            ? 'Online'
            : 'Offline';
    final color = isOnline ? colorScheme.primary : colorScheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── SMS Auto-Track Banner ─────────────────────────────────────────────────────

class _SmsAutoTrackBanner extends StatelessWidget {
  const _SmsAutoTrackBanner({
    required this.detectedCount,
    required this.totalAmount,
  });

  final int detectedCount;
  final int totalAmount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.sms_rounded,
              color: colorScheme.onPrimaryContainer,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📱 Auto-Detected Today: $detectedCount expense${detectedCount == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Money automatically tracked: ₹$totalAmount',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              colorScheme.onPrimaryContainer.withOpacity(0.8),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── How It Works Bottom Sheet ─────────────────────────────────────────────────

class _HowItWorksSheet extends StatelessWidget {
  const _HowItWorksSheet();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    const steps = [
      _HowItWorksStep(
        icon: Icons.add_circle_rounded,
        title: 'Add Expenses',
        description:
            'Tap the "Add Expense" button to log any purchase — enter title, amount, and category manually.',
      ),
      _HowItWorksStep(
        icon: Icons.document_scanner_rounded,
        title: 'Scan Receipts',
        description:
            'Use the camera or gallery to photograph a receipt. ML Kit reads the amount and fills in fields automatically.',
      ),
      _HowItWorksStep(
        icon: Icons.sms_rounded,
        title: 'Auto SMS Detection',
        description:
            'When a bank transaction SMS arrives, PocketPilot detects the amount and merchant — just confirm to save.',
      ),
      _HowItWorksStep(
        icon: Icons.monitor_heart_rounded,
        title: 'Financial Health Score',
        description:
            'A live 0–100 score tracks your budget discipline, daily spending, category balance, and savings rate.',
      ),
      _HowItWorksStep(
        icon: Icons.emoji_events_rounded,
        title: 'Savings Challenges',
        description:
            'Complete daily, weekly, and streak challenges to earn points and unlock Bronze, Silver, and Gold badges.',
      ),
      _HowItWorksStep(
        icon: Icons.cloud_sync_rounded,
        title: 'Cloud Sync',
        description:
            'Your expenses are securely synced via Firebase — access your data on any device after signing in.',
      ),
      _HowItWorksStep(
        icon: Icons.picture_as_pdf_rounded,
        title: 'Export Reports',
        description:
            'Generate a PDF spending report any time and share it via email, WhatsApp, or any app.',
      ),
    ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            // drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.help_outline_rounded,
                      color: colorScheme.primary, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'How It Works',
                    style: textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                itemCount: steps.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (_, i) {
                  final step = steps[i];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(step.icon,
                            color: colorScheme.onPrimaryContainer, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              style: textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              step.description,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HowItWorksStep {
  const _HowItWorksStep({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _ChallengeProgressChip extends StatelessWidget {
  const _ChallengeProgressChip({
    required this.type,
    required this.challenge,
  });

  final ChallengeType type;
  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = (challenge.progress * 100).round();
    final color = _typeColor(type);
    
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_typeIcon(type), color: color, size: 14),
                const SizedBox(width: 4),
                Text(
                  _typeLabel(type),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                if (challenge.isCompleted)
                  Icon(Icons.check_circle_rounded, color: color, size: 14)
                else
                  Text(
                    '$progress%',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: challenge.progress.clamp(0.0, 1.0),
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
              color: color,
              backgroundColor: color.withOpacity(0.2),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(ChallengeType type) {
    switch (type) {
      case ChallengeType.daily:
        return 'Daily';
      case ChallengeType.weekly:
        return 'Weekly';
      case ChallengeType.streak:
        return 'Streak';
    }
  }

  Color _typeColor(ChallengeType type) {
    switch (type) {
      case ChallengeType.daily:
        return const Color(0xFF4CAF50);
      case ChallengeType.weekly:
        return const Color(0xFF2196F3);
      case ChallengeType.streak:
        return const Color(0xFFFF9800);
    }
  }

  IconData _typeIcon(ChallengeType type) {
    switch (type) {
      case ChallengeType.daily:
        return Icons.today_rounded;
      case ChallengeType.weekly:
        return Icons.calendar_view_week_rounded;
      case ChallengeType.streak:
        return Icons.local_fire_department_rounded;
    }
  }
}
