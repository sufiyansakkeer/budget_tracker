import 'package:flutter/foundation.dart';

import '../../../../core/dates/calendar_dates.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../pay_later/domain/repository/pay_later_repository.dart';
import '../entities/activity_extra.dart';

/// Reads what Activity shows beside the expenses of [budgets]: which tab
/// each tab purchase went on, payments to those tabs inside the budgets'
/// periods, and each budget's start (and end, once passed).
///
/// Tabs are best effort: when they can't be read the markers still show.
class GetActivityExtrasUseCase {
  final PayLaterRepository payLater;

  const GetActivityExtrasUseCase(this.payLater);

  Future<ActivityExtras> call({
    required List<BudgetEntity> budgets,
    required DateTime today,
  }) async {
    final day = today.dateOnly;
    final items = <ActivityExtra>[];
    for (final b in budgets) {
      final start = b.startDate.dateOnly;
      final end = b.endDate.dateOnly;
      final days = end.difference(start).inDays + 1;
      BudgetMarkerExtra marker(bool started) => BudgetMarkerExtra(
        budgetId: b.id,
        name: b.name,
        amount: b.monthlyAmount,
        currency: b.currency,
        started: started,
        days: days,
        at: started ? start : end,
      );
      if (!start.isAfter(day)) items.add(marker(true));
      if (end.isBefore(day)) items.add(marker(false));
    }

    final names = <String, String>{};
    try {
      final byId = {for (final b in budgets) b.id: b};
      for (final tab in await payLater.getTabs()) {
        // The budgets this tab bought in, to place its payments.
        final used = <BudgetEntity>{};
        for (final e in await payLater.purchasesOf(tab.id)) {
          final b = byId[e.budgetId];
          if (b == null) continue;
          names[e.id] = tab.name;
          used.add(b);
        }
        if (used.isEmpty) continue;
        for (final p in await payLater.paymentsOf(tab.id)) {
          final paid = p.paidDate.dateOnly;
          final inPeriod = used.any(
            (b) =>
                !paid.isBefore(b.startDate.dateOnly) &&
                !paid.isAfter(b.endDate.dateOnly),
          );
          if (!inPeriod) continue;
          items.add(
            TabPaymentExtra(
              id: p.id,
              tabId: tab.id,
              tabName: tab.name,
              amount: p.amount,
              currency: tab.currency,
              at: _when(p.paidDate, p.createdAt),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[error] Reading tabs for Activity: $e');
      return ActivityExtras(
        items: [
          for (final i in items)
            if (i is BudgetMarkerExtra) i,
        ],
      );
    }
    return ActivityExtras(tabNameByExpense: names, items: items);
  }

  /// A payment's date carries no time; when it was recorded that same day,
  /// the time it was recorded stands in. Otherwise midnight (no time shown).
  static DateTime _when(DateTime paid, DateTime recorded) {
    final atMidnight = paid == paid.dateOnly;
    if (atMidnight && recorded.dateOnly == paid.dateOnly) return recorded;
    return paid;
  }
}
