import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';

/// Date picker field. Does not allow future dates.
class ExpenseDatePicker extends StatelessWidget {
  final DateTime? date;
  final ValueChanged<DateTime> onChanged;

  const ExpenseDatePicker({
    super.key,
    required this.date,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 10, 1, 1);
    final lastDate = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: date ?? now,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select expense date',
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = date == null
        ? 'Select date'
        : DateFormat('EEE, MMM d, yyyy').format(date!);

    return InkWell(
      key: const Key('expenseDatePicker'),
      onTap: () => _pick(context),
      borderRadius: AppSpacing.borderRadiusMd,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date',
          prefixIcon: Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          display,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: date == null ? FontWeight.w400 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
