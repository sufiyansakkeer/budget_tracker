import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/dates/calendar_dates.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/dates/date_range_format.dart';

/// Date picker field. Does not allow future dates.
///
/// With [budget], only that budget's days up to today can be picked, as in
/// quick add; the save still checks the date (the budget can change after
/// the date was picked). A budget that hasn't started yet has no such
/// days, so the usual range is offered and the save explains.
class ExpenseDatePicker extends StatelessWidget {
  final DateTime? date;
  final ValueChanged<DateTime> onChanged;
  final String? errorText;

  /// The budget the expense goes to, when known.
  final BudgetEntity? budget;

  const ExpenseDatePicker({
    super.key,
    required this.date,
    required this.onChanged,
    this.errorText,
    this.budget,
  });

  /// The days the picker offers: [budget]'s period up to today, or the
  /// last ten years up to today.
  @visibleForTesting
  static ({DateTime first, DateTime last}) rangeFor(
    BudgetEntity? budget,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    if (budget != null) {
      final start = DateTime(
        budget.startDate.year,
        budget.startDate.month,
        budget.startDate.day,
      );
      final end = DateTime(
        budget.endDate.year,
        budget.endDate.month,
        budget.endDate.day,
      );
      final last = end.isBefore(today) ? end : today;
      if (!last.isBefore(start)) return (first: start, last: last);
    }
    return (first: DateTime(now.year - 10, 1, 1), last: today);
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final (:first, :last) = rangeFor(budget, now);
    final initial = date ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(last)
          ? last
          : (initial.isBefore(first) ? first : initial),
      firstDate: first,
      lastDate: last,
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
      } else if (day == today.addDays(-1)) {
        display = 'Yesterday';
      } else {
        display = AppDates.fullDay(date!);
      }
    }

    return Semantics(
      button: true,
      // The error is read with the field: the decorator's own text is
      // excluded below.
      label: errorText == null
          ? 'Date, $display'
          : 'Date, $display, $errorText',
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
