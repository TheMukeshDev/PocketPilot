import 'package:flutter/material.dart';

class BudgetCard extends StatelessWidget {
  const BudgetCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.backgroundColor,
    this.valueColor,
    this.emphasize = false,
  });

  final String title;
  final String value;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? valueColor;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: emphasize ? 2.5 : 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      shadowColor: colorScheme.shadow.withOpacity(0.14),
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (icon != null)
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
            if (icon != null) const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
