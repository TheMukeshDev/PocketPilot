import 'dart:math';

import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../services/auth_service.dart';
import '../services/expense_service.dart';
import '../services/notification_preferences_service.dart';
import '../widgets/main_bottom_nav.dart';
import '../widgets/notification_tile.dart';
import 'add_expense_screen.dart';
import 'payment_history_screen.dart';
import 'scan_receipt_screen.dart';
import 'scan_qr_payment_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({
    super.key,
    required this.alertMessages,
  });

  final List<String> alertMessages;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _tips = <String>[
    'Set a daily limit and track before every payment.',
    'Save ₹10 first thing in the morning for consistency.',
    'Reduce one non-essential purchase today.',
    'Check top expense category and cut it by 10%.',
    'Review all UPI spends nightly for better control.',
  ];

  late TabController _tabController;
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  late String _todayTip;

  @override
  void initState() {
    super.initState();
    final random = Random(DateTime.now().day + DateTime.now().month);
    _todayTip = _tips[random.nextInt(_tips.length)];
    _tabController = TabController(length: 2, vsync: this);
    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final notifications =
          await NotificationPreferencesService.instance.loadNotificationHistory();
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(AppNotification notification) async {
    await NotificationPreferencesService.instance
        .markNotificationAsRead(notification.id);
    _loadNotifications();
  }

  Future<void> _dismissNotification(AppNotification notification) async {
    final updated = _notifications.where((n) => n.id != notification.id).toList();
    await NotificationPreferencesService.instance.saveNotificationHistory(updated);
    setState(() => _notifications = updated);
  }

  Future<void> _markAllAsRead() async {
    await NotificationPreferencesService.instance.markAllNotificationsAsRead();
    _loadNotifications();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('This will remove all notification history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await NotificationPreferencesService.instance.clearNotificationHistory();
      _loadNotifications();
    }
  }

  Future<void> _openPayFlow() async {
    final paidExpense = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(builder: (_) => const ScanQrPaymentScreen()),
    );

    if (paidExpense == null || !mounted) {
      return;
    }

    await ExpenseService.instance.addExpense(
      paidExpense,
      AuthService.instance.currentUser,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment added to expense history.')),
    );
  }

  Future<void> _openHistory() async {
    final expenses = await ExpenseService.instance.getExpensesForUser(
      AuthService.instance.currentUser,
    );
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaymentHistoryScreen(expenses: expenses),
      ),
    );
  }

  Future<void> _openAddReceiptFlow() async {
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
                title: const Text('Scan Receipt'),
                subtitle: const Text('Use camera/gallery auto-detection'),
                onTap: () => Navigator.of(sheetContext).pop('scan'),
              ),
              ListTile(
                leading: const Icon(Icons.edit_note_rounded),
                title: const Text('Add Manually'),
                subtitle: const Text('Enter title, amount and category'),
                onTap: () => Navigator.of(sheetContext).pop('manual'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == 'manual') {
      await Navigator.of(context).push<dynamic>(
        MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
      );
    } else {
      await Navigator.of(context).push<dynamic>(
        MaterialPageRoute(builder: (_) => const ScanReceiptScreen()),
      );
    }

    if (!mounted) return;
    _loadNotifications();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt expense added.')),
    );
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final primaryAlert = widget.alertMessages.isNotEmpty
        ? widget.alertMessages.first
        : 'No critical alert right now. Great budget control!';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Alerts'),
                  if (widget.alertMessages.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.alertMessages.length}',
                        style: TextStyle(
                          color: colorScheme.onError,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('History'),
                  if (_unreadCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_unreadCount',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_tabController.index == 1 && _notifications.isNotEmpty) ...[
            if (_unreadCount > 0)
              TextButton(
                onPressed: _markAllAsRead,
                child: const Text('Mark all read'),
              ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'clear') {
                  _clearAll();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded),
                      SizedBox(width: 10),
                      Text('Clear all'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar: MainBottomNav(
        currentTab: AppBottomTab.alerts,
        alertsCount: widget.alertMessages.length,
        onHomeTap: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        onAlertsTap: () {},
        onPayTap: _openPayFlow,
        onAddReceiptTap: _openAddReceiptFlow,
        onHistoryTap: _openHistory,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAlertsTab(primaryAlert, textTheme, colorScheme),
          _buildHistoryTab(colorScheme),
        ],
      ),
    );
  }

  Widget _buildAlertsTab(
    String primaryAlert,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
      children: [
        Card(
          color: colorScheme.errorContainer.withOpacity(0.5),
          child: ListTile(
            leading: Icon(
              Icons.warning_amber_rounded,
              color: colorScheme.error,
            ),
            title: const Text('Primary Alert'),
            subtitle: Text(
              primaryAlert,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...widget.alertMessages.skip(1).map(
              (message) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.info_outline_rounded,
                      color: colorScheme.primary,
                    ),
                    title: Text(message),
                  ),
                ),
              ),
            ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: Icon(
              Icons.lightbulb_outline_rounded,
              color: colorScheme.tertiary,
            ),
            title: const Text('Today\'s Savings Suggestion'),
            subtitle: Text(_todayTip),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notifications.isEmpty) {
      return const NotificationEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 130),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: NotificationTile(
              notification: notification,
              onTap: () => _markAsRead(notification),
              onDismiss: () => _dismissNotification(notification),
            ),
          );
        },
      ),
    );
  }
}

class NotificationEmptyState extends StatelessWidget {
  const NotificationEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 40,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No notifications yet',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ll see notifications here when you:\n'
              '- Exceed your daily spending limit\n'
              '- Complete savings challenges\n'
              '- Earn points and badges\n'
              '- Receive engagement reminders',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
