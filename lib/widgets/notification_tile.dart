import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_notification.dart';

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    this.onDismiss,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_rounded,
          color: colorScheme.onError,
        ),
      ),
      child: Card(
        elevation: notification.isRead ? 0.5 : 1.5,
        color: notification.isRead
            ? (colorScheme.surfaceVariant.withOpacity(0.5))
            : colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: notification.isRead
              ? BorderSide.none
              : BorderSide(
                  color: _getTypeColor(colorScheme).withOpacity(0.3),
                  width: 1,
                ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIcon(colorScheme),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: notification.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _getTypeColor(colorScheme),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatTimestamp(notification.createdAt),
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(ColorScheme colorScheme) {
    final iconData = _getIcon();
    final color = _getTypeColor(colorScheme);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        color: color,
        size: 22,
      ),
    );
  }

  IconData _getIcon() {
    switch (notification.type) {
      case NotificationType.budget:
        return Icons.warning_amber_rounded;
      case NotificationType.streak:
        return Icons.local_fire_department_rounded;
      case NotificationType.reward:
        return Icons.emoji_events_rounded;
      case NotificationType.reminder:
        return Icons.notifications_active_rounded;
    }
  }

  Color _getTypeColor(ColorScheme colorScheme) {
    switch (notification.type) {
      case NotificationType.budget:
        return colorScheme.error;
      case NotificationType.streak:
        return Colors.orange;
      case NotificationType.reward:
        return Colors.amber;
      case NotificationType.reminder:
        return colorScheme.primary;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final notificationDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    final timeStr = DateFormat.jm().format(timestamp);

    if (notificationDate == today) {
      return 'Today at $timeStr';
    } else if (notificationDate == yesterday) {
      return 'Yesterday at $timeStr';
    } else if (now.difference(timestamp).inDays < 7) {
      return DateFormat('EEEE').format(timestamp) + ' at $timeStr';
    } else {
      return DateFormat('MMM d, y').format(timestamp) + ' at $timeStr';
    }
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
