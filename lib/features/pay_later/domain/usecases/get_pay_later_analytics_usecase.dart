import 'dart:developer' as developer;
import 'dart:math' as math;

import '../../../../core/currency/money_math.dart';
import '../../../../core/dates/calendar_dates.dart';
import '../entities/pay_later_failure.dart';
import '../entities/pay_later_overview.dart';
import '../entities/tab_ledger.dart';
import 'get_tab_ledger_usecase.dart';
import 'get_tabs_usecase.dart';
import 'load_tab_ledgers.dart';

/// Charts and breakdowns for every tab in one currency, or for one tab
/// (spec §7). Reads only; archived tabs are included because their history
/// still happened.
class GetPayLaterAnalyticsUseCase {
  /// How many calendar months the charts cover, this one included.
  static const int monthCount = 6;

  final GetTabsUseCase _getTabs;
  final GetTabLedgerUseCase _getLedger;
  final DateTime Function() _clock;

  GetPayLaterAnalyticsUseCase({
    required GetTabsUseCase getTabs,
    required GetTabLedgerUseCase getLedger,
    DateTime Function()? clock,
  }) : _getTabs = getTabs,
       _getLedger = getLedger,
       _clock = clock ?? DateTime.now;

  /// Every tab in [currency]; with [tabId], only that tab, which must be in
  /// [currency].
  Future<PayLaterResult<PayLaterAnalytics>> call({
    required String currency,
    String? tabId,
  }) async {
    try {
      final loaded = await loadTabLedgers(
        getTabs: _getTabs,
        getLedger: _getLedger,
        where: (tab) =>
            tabId == null ? tab.currency == currency : tab.id == tabId,
      );
      final List<TabLedger> ledgers;
      switch (loaded) {
        case PayLaterError(:final failure):
          return PayLaterError(failure);
        case PayLaterSuccess(:final data):
          ledgers = data;
      }
      if (tabId != null) {
        if (ledgers.isEmpty) {
          return const PayLaterError(
            PayLaterFailure(
              type: PayLaterErrorType.notFound,
              message: 'Tab not found',
            ),
          );
        }
        if (ledgers.single.tab.currency != currency) {
          return const PayLaterError(
            PayLaterFailure(
              type: PayLaterErrorType.invalidInput,
              message: "This tab's figures are in another currency.",
            ),
          );
        }
      }
      return PayLaterSuccess(
        _build(
          currency,
          ledgers,
          _clock().dateOnly,
          periods: tabId == null ? const [] : ledgers.single.periods,
        ),
      );
    } catch (e) {
      developer.log(
        'Failed to build Pay later analytics: $e',
        name: 'GetPayLaterAnalytics',
      );
      return PayLaterError(
        PayLaterFailure(
          type: PayLaterErrorType.databaseFailure,
          message: 'Failed to load Pay later charts: $e',
        ),
      );
    }
  }

  PayLaterAnalytics _build(
    String currency,
    List<TabLedger> ledgers,
    DateTime today, {
    required List<PeriodSummary> periods,
  }) {
    final money = MoneyMath.forCurrency(currency);
    final purchases = [for (final l in ledgers) ...l.purchases];
    final payments = [for (final l in ledgers) ...l.payments];

    final months = <MonthPoint>[];
    for (var back = monthCount - 1; back >= 0; back--) {
      final start = DateTime(today.year, today.month - back);
      final next = DateTime(start.year, start.month + 1);
      bool inMonth(DateTime date) {
        final day = date.dateOnly;
        return !day.isBefore(start) && day.isBefore(next);
      }

      // Per tab, the same identity as a payment's balance after: everything
      // dated up to the month's last day, purchases minus payments. A tab
      // in credit owes nothing, and its credit never offsets another tab's
      // debt, so this month's point equals the headline owed (Σ tab owed).
      bool byEnd(DateTime date) => date.dateOnly.isBefore(next);

      var owedUnits = 0;
      for (final ledger in ledgers) {
        final purchasedToEnd = money.sumUnits([
          for (final p in ledger.purchases)
            if (byEnd(p.expense.date)) p.expense.amount,
        ]);
        final paidToEnd = money.sumUnits([
          for (final p in ledger.payments)
            if (byEnd(p.payment.paidDate)) p.payment.amount,
        ]);
        owedUnits += math.max(0, purchasedToEnd - paidToEnd);
      }
      months.add(
        MonthPoint(
          month: start,
          added: money.toAmount(
            money.sumUnits([
              for (final p in purchases)
                if (inMonth(p.expense.date)) p.expense.amount,
            ]),
          ),
          paid: money.toAmount(
            money.sumUnits([
              for (final p in payments)
                if (inMonth(p.payment.paidDate)) p.payment.amount,
            ]),
          ),
          owedAtEnd: money.toAmount(owedUnits),
        ),
      );
    }

    final byCategory = <String, int>{};
    for (final line in purchases) {
      final units = money.toUnits(line.expense.amount);
      byCategory.update(
        line.expense.categoryId,
        (v) => v + units,
        ifAbsent: () => units,
      );
    }
    final byTab = <String, double>{
      for (final ledger in ledgers)
        if (ledger.purchases.isNotEmpty)
          ledger.tab.id: money.toAmount(
            money.sumUnits(ledger.purchases.map((l) => l.expense.amount)),
          ),
    };

    return PayLaterAnalytics(
      currency: currency,
      months: months,
      byExpenseCategory: {
        for (final MapEntry(key: id, value: units) in byCategory.entries)
          id: money.toAmount(units),
      },
      byTab: byTab,
      periodComparison: periods,
    );
  }
}
