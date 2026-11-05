import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../core/dates/calendar_dates.dart';
import '../../../core/domain/entities/budget_entity.dart';
import '../../../core/navigation/push_unique.dart';

/// "Start next period": a new budget that carries on from one that ended,
/// with the same amount, currency and set-asides, starting the day after it
/// ends. The one entry point for every screen that offers it.
abstract final class StartNextPeriod {
  /// The budget form, prefilled from [budgetId]'s budget.
  static String location(String budgetId) =>
      '/app/budgets/create?next=${Uri.encodeQueryComponent(budgetId)}';

  /// Opens the budget form prefilled with the period after [budgetId]'s,
  /// then, once it is created, the new budget's details. Completes with the
  /// new budget's id, or null when the form was left without creating one.
  /// [context] must be under the app's router and outlive the form (a
  /// screen, not a sheet that closes).
  static Future<String?> open(BuildContext context, String budgetId) async {
    final created = await context.pushUnique<Object?>(location(budgetId));
    if (created is! String || !context.mounted) return null;
    unawaited(context.pushUnique('/app/budgets/$created'));
    return created;
  }

  /// The period after [budget]'s: from the day after it ends, for as many
  /// days. A budget that runs one calendar month from its start day (1–31
  /// Oct, 15 Oct–14 Nov) continues to the same day a month on instead, so
  /// 1–31 Oct is followed by 1–30 Nov, not 1 Nov–1 Dec.
  static ({DateTime start, DateTime end}) datesAfter(BudgetEntity budget) {
    final start = budget.startDate.dateOnly;
    final end = budget.endDate.dateOnly;
    final nextStart = end.addDays(1);
    final monthly = _monthOn(start).addDays(-1) == end;
    return (
      start: nextStart,
      end: monthly
          ? _monthOn(nextStart).addDays(-1)
          : nextStart.addDays(calendarDaysBetween(start, end)),
    );
  }

  /// The same day of the next month, or its last day when shorter.
  static DateTime _monthOn(DateTime date) {
    final daysInNext = DateTime(date.year, date.month + 2, 0).day;
    return DateTime(date.year, date.month + 1, math.min(date.day, daysInNext));
  }
}
