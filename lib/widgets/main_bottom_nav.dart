import 'package:flutter/material.dart';

enum AppBottomTab { home, alerts, pay, addReceipt, history }

class MainBottomNav extends StatelessWidget {
  const MainBottomNav({
    super.key,
    required this.currentTab,
    required this.onHomeTap,
    required this.onAlertsTap,
    required this.onPayTap,
    required this.onAddReceiptTap,
    required this.onHistoryTap,
    this.alertsCount = 0,
  });

  final AppBottomTab currentTab;
  final VoidCallback onHomeTap;
  final VoidCallback onAlertsTap;
  final VoidCallback onPayTap;
  final VoidCallback onAddReceiptTap;
  final VoidCallback onHistoryTap;
  final int alertsCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 88,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _BottomNavItem(
                      icon: Icons.home_rounded,
                      label: 'Home',
                      active: currentTab == AppBottomTab.home,
                      onTap: onHomeTap,
                    ),
                  ),
                  Expanded(
                    child: _BottomNavItem(
                      icon: Icons.notifications_rounded,
                      label: 'Alerts',
                      active: currentTab == AppBottomTab.alerts,
                      onTap: onAlertsTap,
                      badgeCount: alertsCount,
                    ),
                  ),
                  const SizedBox(width: 78),
                  Expanded(
                    child: _BottomNavItem(
                      icon: Icons.add_card_rounded,
                      label: 'Add',
                      active: currentTab == AppBottomTab.addReceipt,
                      onTap: onAddReceiptTap,
                    ),
                  ),
                  Expanded(
                    child: _BottomNavItem(
                      icon: Icons.history_rounded,
                      label: 'History',
                      active: currentTab == AppBottomTab.history,
                      onTap: onHistoryTap,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -26,
            child: GestureDetector(
              onTap: onPayTap,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withOpacity(0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: colorScheme.surface, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      color: colorScheme.onPrimary,
                      size: 30,
                    ),
                    Text(
                      'Pay',
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor =
        active ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 24, color: iconColor),
                if (badgeCount > 0)
                  Positioned(
                    right: -7,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: colorScheme.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        style: TextStyle(
                          color: colorScheme.onError,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
