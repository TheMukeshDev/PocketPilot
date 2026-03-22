import 'package:flutter/material.dart';

class BudgetOverviewCard extends StatelessWidget {
  const BudgetOverviewCard({
    super.key,
    required this.monthlyBudget,
    required this.rent,
    required this.totalSpent,
    required this.todaySpent,
    required this.remaining,
    required this.dailyLimit,
  });

  final int monthlyBudget;
  final int rent;
  final int totalSpent;
  final int todaySpent;
  final int remaining;
  final int dailyLimit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOverBudget = remaining < 0;
    final isOverDaily = dailyLimit > 0 && todaySpent > dailyLimit;
    
    final spendProgress = monthlyBudget > 0 
        ? (totalSpent / monthlyBudget).clamp(0.0, 1.0) 
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isOverBudget
              ? [colorScheme.error, colorScheme.errorContainer]
              : [colorScheme.primary, colorScheme.primaryContainer],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isOverBudget ? colorScheme.error : colorScheme.primary).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Left to Spend',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isOverBudget ? '-₹${remaining.abs()}' : '₹$remaining',
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'of ₹$monthlyBudget',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${((1 - spendProgress) * 100).round()}% remaining',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MetricRow(
                    label: 'Today',
                    value: '₹$todaySpent',
                    icon: Icons.today_rounded,
                    isWarning: isOverDaily,
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withOpacity(0.2),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                Expanded(
                  child: _MetricRow(
                    label: 'Daily Limit',
                    value: '₹$dailyLimit',
                    icon: Icons.speed_rounded,
                    isWarning: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricRow(
                    label: 'Budget',
                    value: '₹$monthlyBudget',
                    icon: Icons.account_balance_wallet_rounded,
                    isWarning: false,
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withOpacity(0.2),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                Expanded(
                  child: _MetricRow(
                    label: 'Rent',
                    value: '₹$rent',
                    icon: Icons.home_work_rounded,
                    isWarning: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricRow(
                    label: 'Spent',
                    value: '₹$totalSpent',
                    icon: Icons.payments_rounded,
                    isWarning: false,
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withOpacity(0.2),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up_rounded,
                            size: 14,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Usage',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: spendProgress,
                          minHeight: 6,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          color: isOverBudget ? Colors.white : Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.isWarning,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isWarning ? Colors.white : Colors.white.withOpacity(0.7),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isWarning ? Colors.white : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DailySpendProgress extends StatelessWidget {
  const DailySpendProgress({
    super.key,
    required this.todaySpent,
    required this.dailyLimit,
  });

  final int todaySpent;
  final int dailyLimit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = dailyLimit > 0 ? (todaySpent / dailyLimit).clamp(0.0, 1.0) : 0.0;
    final isOver = todaySpent > dailyLimit && dailyLimit > 0;
    final remaining = dailyLimit - todaySpent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.speed_rounded,
                    size: 18,
                    color: isOver ? colorScheme.error : colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Daily Progress',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Text(
                isOver 
                    ? 'Over by ₹${remaining.abs()}' 
                    : '₹$remaining left',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isOver ? colorScheme.error : colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: colorScheme.surface,
              color: isOver ? colorScheme.error : colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹$todaySpent spent',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '₹$dailyLimit limit',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CompactMetricTile extends StatelessWidget {
  const CompactMetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.backgroundColor,
    this.isCompact = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Color? backgroundColor;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = backgroundColor ?? colorScheme.surfaceVariant;
    final txtColor = valueColor ?? colorScheme.onSurface;

    return Container(
      padding: EdgeInsets.all(isCompact ? 10 : 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isCompact ? 15 : 17,
                    fontWeight: FontWeight.w700,
                    color: txtColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
