import 'package:flutter/material.dart';

import '../services/prediction_service.dart';

class PredictionCard extends StatelessWidget {
  const PredictionCard({super.key, required this.prediction});

  final PredictionResult prediction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final warning = prediction.isLikelyToOverspend;
    final onContainerColor = warning
        ? colorScheme.onErrorContainer
        : colorScheme.onTertiaryContainer;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      color:
          warning ? colorScheme.errorContainer : colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  warning ? Icons.warning_rounded : Icons.auto_graph_rounded,
                  color: onContainerColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Overspend Prediction',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: onContainerColor,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              prediction.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: onContainerColor,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Based on cycle day ${prediction.currentDay} of ${prediction.daysInMonth}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: onContainerColor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Daily average: ₹${prediction.dailyAverageSpend.toStringAsFixed(0)} / day\n'
              'Predicted month spend: ₹${prediction.predictedMonthSpend.toStringAsFixed(0)}\n'
              'Available budget: ₹${prediction.availableBudget}',
              style: TextStyle(color: onContainerColor),
            ),
            if (warning) ...[
              const SizedBox(height: 10),
              Text(
                'Likely over by: ${prediction.overspendPercent.toStringAsFixed(1)}% '
                '(₹${prediction.overspendAmount.toStringAsFixed(0)})',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: onContainerColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Quick tips:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: onContainerColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '• Cut food spend by ₹${prediction.cutFoodPerDayTip}/day for the remaining days\n'
                '• ${prediction.skipOttTip}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: onContainerColor,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
