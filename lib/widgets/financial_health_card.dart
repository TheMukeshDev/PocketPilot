import 'package:flutter/material.dart';

import '../services/financial_score_service.dart';

class FinancialHealthCard extends StatelessWidget {
  const FinancialHealthCard({
    super.key,
    required this.breakdown,
  });

  final FinancialScoreBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(context, breakdown.totalScore);
    final percentileText = _getPercentileText(breakdown.totalScore);

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
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withOpacity(0.14),
                  child: Icon(
                    Icons.health_and_safety_rounded,
                    color: color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Financial Health',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        breakdown.status,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${breakdown.totalScore}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: breakdown.totalScore / 100,
                minHeight: 8,
                backgroundColor: color.withOpacity(0.15),
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.insights_rounded,
                    color: color,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      breakdown.primaryInsight,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      breakdown.suggestion,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (percentileText.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          color: Color(0xFF4CAF50),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          percentileText,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: const Color(0xFF4CAF50),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    'Score breakdown:',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _MiniScoreChip(
                  label: 'Budget',
                  value: breakdown.budgetDiscipline,
                  maxValue: 40,
                ),
                const SizedBox(width: 8),
                _MiniScoreChip(
                  label: 'Daily',
                  value: breakdown.dailyDiscipline,
                  maxValue: 20,
                ),
                const SizedBox(width: 8),
                _MiniScoreChip(
                  label: 'Spread',
                  value: breakdown.spendingDistribution,
                  maxValue: 20,
                ),
                const SizedBox(width: 8),
                _MiniScoreChip(
                  label: 'Savings',
                  value: breakdown.savingRate,
                  maxValue: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getPercentileText(int score) {
    if (score >= 90) {
      return 'Top 10% savers';
    } else if (score >= 75) {
      return 'Top 25% savers';
    } else if (score >= 60) {
      return 'Top 50% savers';
    }
    return '';
  }

  Color _scoreColor(BuildContext context, int score) {
    final scheme = Theme.of(context).colorScheme;
    if (score < 40) {
      return scheme.error;
    }
    if (score < 70) {
      return Colors.orange;
    }
    if (score < 90) {
      return scheme.primary;
    }
    return const Color(0xFF4CAF50);
  }
}

class _MiniScoreChip extends StatelessWidget {
  const _MiniScoreChip({
    required this.label,
    required this.value,
    required this.maxValue,
  });

  final String label;
  final int value;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
