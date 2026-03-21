import 'package:flutter/material.dart';

import '../services/date_cycle_service.dart';

class SmartDateSelector extends StatefulWidget {
  const SmartDateSelector({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.label = 'Select Date',
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final String label;

  @override
  State<SmartDateSelector> createState() => _SmartDateSelectorState();
}

class _SmartDateSelectorState extends State<SmartDateSelector> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
  }

  @override
  void didUpdateWidget(SmartDateSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _selectedDate = widget.selectedDate;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      widget.onDateSelected(picked);
    }
  }

  void _selectQuickDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    widget.onDateSelected(date);
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dateService = DateCycleService.instance;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _CompactDateChip(
                label: 'Today',
                isSelected: _isSameDate(_selectedDate, today),
                onTap: () => _selectQuickDate(today),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CompactDateChip(
                label: 'Tomorrow',
                isSelected: _isSameDate(_selectedDate, tomorrow),
                onTap: () => _selectQuickDate(tomorrow),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _CompactDateChip(
                label: 'Yesterday',
                isSelected: _isSameDate(_selectedDate, yesterday),
                onTap: () => _selectQuickDate(yesterday),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CompactDateChip(
                label: 'Choose',
                isSelected: !_isSameDate(_selectedDate, today) &&
                    !_isSameDate(_selectedDate, tomorrow) &&
                    !_isSameDate(_selectedDate, yesterday),
                onTap: () => _selectDate(context),
                icon: Icons.calendar_today_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.event, size: 14, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              dateService.formatDate(_selectedDate),
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
            const Spacer(),
            Text(
              '${dateService.formatDate(dateService.getCycleStart(_selectedDate))} → ${dateService.formatDate(dateService.getCycleEnd(_selectedDate))}',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactDateChip extends StatelessWidget {
  const _CompactDateChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: isSelected 
          ? colorScheme.primaryContainer 
          : colorScheme.surfaceVariant,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: colorScheme.primary, width: 1.5)
                : Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: isSelected 
                      ? colorScheme.onPrimaryContainer 
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected 
                      ? colorScheme.onPrimaryContainer 
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
