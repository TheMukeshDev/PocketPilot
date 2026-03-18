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
                  child: Text(
                    'Financial Health Score',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Text(
                  '${breakdown.totalScore} / 100',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              breakdown.status,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: breakdown.totalScore / 100,
              minHeight: 9,
              borderRadius: BorderRadius.circular(99),
              color: color,
              backgroundColor: color.withOpacity(0.16),
            ),
            const SizedBox(height: 12),
            Text(
              breakdown.primaryInsight,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '💡 ${breakdown.suggestion}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            _SubScoreRow(
              label: 'Budget Discipline',
              value: '${breakdown.budgetDiscipline} / 40',
            ),
            _SubScoreRow(
              label: 'Daily Limit Discipline',
              value: '${breakdown.dailyDiscipline} / 20',
            ),
            _SubScoreRow(
              label: 'Spending Distribution',
              value: '${breakdown.spendingDistribution} / 20',
            ),
            _SubScoreRow(
              label: 'Saving Rate',
              value: '${breakdown.savingRate} / 20',
            ),
          ],
        ),
      ),
    );
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
    return Colors.green.shade700;
  }
}

class _SubScoreRow extends StatelessWidget {
  const _SubScoreRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
