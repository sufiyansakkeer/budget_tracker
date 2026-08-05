import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';

/// Time picker field.
class ExpenseTimePicker extends StatelessWidget {
  final TimeOfDay? time;
  final ValueChanged<TimeOfDay> onChanged;

  const ExpenseTimePicker({
    super.key,
    required this.time,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: time ?? TimeOfDay.now(),
      helpText: 'Select expense time',
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = time == null
        ? 'Select time'
        : DateFormat(
            'h:mm a',
          ).format(DateTime(2000, 1, 1, time!.hour, time!.minute));

    return InkWell(
      key: const Key('expenseTimePicker'),
      onTap: () => _pick(context),
      borderRadius: AppSpacing.borderRadiusMd,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Time',
          prefixIcon: Icon(Icons.access_time),
        ),
        child: Text(
          display,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: time == null ? FontWeight.w400 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
