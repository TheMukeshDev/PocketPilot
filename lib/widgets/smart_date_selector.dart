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

  @override
  Widget build(BuildContext context) {
    final dateService = DateCycleService.instance;
    final quickOptions = dateService.getQuickDateOptions();
    final quickLabels = dateService.getQuickDateLabels();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),

        // Quick date chips (Today / Yesterday / Tomorrow / Calendar)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int i = 0; i < quickOptions.length; i++)
              ChoiceChip(
                label: Text(quickLabels[i], softWrap: false),
                selected: _isSameDate(_selectedDate, quickOptions[i]),
                selectedColor: Theme.of(context).colorScheme.primaryContainer,
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                onSelected: (_) => _selectQuickDate(quickOptions[i]),
              ),
            ActionChip(
              label: const Text('Choose from Calendar'),
              avatar: const Icon(Icons.calendar_month, size: 18),
              onPressed: () => _selectDate(context),
            ),
          ],
        ),

        const SizedBox(height: 4),

        // Selected date summary
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event, size: 18),
            const SizedBox(width: 6),
            Text(
              dateService.formatDate(_selectedDate),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),

        const SizedBox(height: 4),
        // Cycle info (if applicable)
        Text(
          'Cycle: ${dateService.formatDate(dateService.getCycleStart(_selectedDate))} → ${dateService.formatDate(dateService.getCycleEnd(_selectedDate))}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
