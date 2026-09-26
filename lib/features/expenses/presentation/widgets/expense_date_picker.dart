import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';

/// Date picker field. Does not allow future dates.
class ExpenseDatePicker extends StatelessWidget {
  final DateTime? date;
  final ValueChanged<DateTime> onChanged;
  final String? errorText;

  const ExpenseDatePicker({
    super.key,
    required this.date,
    required this.onChanged,
    this.errorText,
  });

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 10, 1, 1);
    final lastDate = DateTime(now.year, now.month, now.day);
    final initial = date ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(lastDate) ? lastDate : initial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Expense date',
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final String display;
    if (date == null) {
      display = 'Select date';
    } else {
      final day = DateTime(date!.year, date!.month, date!.day);
      if (day == today) {
        display = 'Today';
      } else if (day == today.subtract(const Duration(days: 1))) {
        display = 'Yesterday';
      } else {
        display = DateFormat('EEE, d MMM yyyy').format(date!);
      }
    }

    return Semantics(
      button: true,
      label: 'Date, $display',
      onTap: () => _pick(context),
      excludeSemantics: true,
      child: InkWell(
        key: const Key('expenseDatePicker'),
        onTap: () => _pick(context),
        borderRadius: AppSpacing.borderRadiusMd,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Date',
            prefixIcon: const Icon(Icons.calendar_today_outlined),
            errorText: errorText,
          ),
          child: Text(
            display,
            style: theme.textTheme.bodyLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
