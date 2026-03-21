import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../services/auth_service.dart';
import '../services/expense_service.dart';
import '../services/notification_preferences_service.dart';
import '../widgets/main_bottom_nav.dart';
import '../widgets/notification_tile.dart';
import 'add_expense_screen.dart';
import 'payment_history_screen.dart';
import 'scan_qr_payment_screen.dart';
import 'scan_receipt_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    this.alertMessages = const [],
  });

  final List<String> alertMessages;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
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

  Future<void> _markAllAsRead() async {
    await NotificationPreferencesService.instance.markAllNotificationsAsRead();
    _loadNotifications();
  }

  Future<void> _dismissNotification(AppNotification notification) async {
    final updated = _notifications.where((n) => n.id != notification.id).toList();
    await NotificationPreferencesService.instance.saveNotificationHistory(updated);
    setState(() => _notifications = updated);
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
    final paidExpense = await Navigator.of(context).push<AppNotification?>(
      MaterialPageRoute(builder: (_) => const ScanQrPaymentScreen()),
    );

    if (paidExpense == null || !mounted) {
      return;
    }

    await ExpenseService.instance.addExpense(
      paidExpense as dynamic,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_notifications.isNotEmpty) ...[
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const NotificationEmptyState()
              : RefreshIndicator(
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
                ),
    );
  }
}
