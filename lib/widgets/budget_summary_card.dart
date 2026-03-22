import 'package:flutter/material.dart';

class BudgetSummaryCard extends StatelessWidget {
  const BudgetSummaryCard({
    super.key,
    required this.monthlyBudget,
    required this.rent,
    required this.totalSpent,
    required this.todaySpent,
    required this.dailyLimit,
    required this.remaining,
  });

  final int monthlyBudget;
  final int rent;
  final int totalSpent;
  final int todaySpent;
  final int dailyLimit;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final spentPercent = monthlyBudget > 0 ? (totalSpent / monthlyBudget) : 0.0;
    final isOverBudget = totalSpent > monthlyBudget;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Budget Overview',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _BudgetStat(
                    label: 'Monthly Budget',
                    value: '₹$monthlyBudget',
                    color: colorScheme.primary,
                    icon: Icons.calendar_month_rounded,
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: colorScheme.outlineVariant,
                ),
                Expanded(
                  child: _BudgetStat(
                    label: 'Fixed Rent',
                    value: '₹$rent',
                    color: colorScheme.secondary,
                    icon: Icons.home_work_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: spentPercent.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: colorScheme.surfaceVariant,
                color: isOverBudget
                    ? colorScheme.error
                    : spentPercent > 0.8
                        ? Colors.orange
                        : const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Spent: ₹$totalSpent / ₹$monthlyBudget',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                Text(
                  '${(spentPercent * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isOverBudget
                            ? colorScheme.error
                            : colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Left to Spend',
                    value: remaining >= 0 ? '₹$remaining' : '-₹${remaining.abs()}',
                    color: remaining >= 0 ? const Color(0xFF4CAF50) : colorScheme.error,
                    isHighlighted: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStat(
                    label: 'Daily Limit',
                    value: '₹$dailyLimit',
                    color: colorScheme.tertiary,
                    isHighlighted: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStat(
                    label: 'Today',
                    value: '₹$todaySpent',
                    color: todaySpent > dailyLimit
                        ? colorScheme.error
                        : colorScheme.secondary,
                    isHighlighted: false,
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

class _BudgetStat extends StatelessWidget {
  const _BudgetStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.isHighlighted,
  });

  final String label;
  final String value;
  final Color color;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(isHighlighted ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
