import 'dart:developer' as developer;

import '../../../../core/currency/money_math.dart';
import '../../../../core/dates/calendar_dates.dart';
import '../entities/pay_later_failure.dart';
import '../entities/pay_later_overview.dart';
import '../entities/pay_later_tab.dart';
import '../entities/tab_ledger.dart';
import 'get_tab_ledger_usecase.dart';
import 'get_tabs_usecase.dart';
import 'load_tab_ledgers.dart';
import '../services/fifo_order.dart';

/// Builds the Pay later overview (spec §7) from every tab's ledger. Reads
/// only.
///
/// Debt is never hidden: an archived tab that still owes or holds credit
/// is listed with the active tabs and counts in its currency's totals.
/// Totals are kept per currency and summed in that currency's units.
class GetPayLaterOverviewUseCase {
  final GetTabsUseCase _getTabs;
  final GetTabLedgerUseCase _getLedger;
  final DateTime Function() _clock;

  GetPayLaterOverviewUseCase({
    required GetTabsUseCase getTabs,
    required GetTabLedgerUseCase getLedger,
    DateTime Function()? clock,
  }) : _getTabs = getTabs,
       _getLedger = getLedger,
       _clock = clock ?? DateTime.now;

  Future<PayLaterResult<PayLaterOverview>> call() async {
    try {
      final loaded = await loadTabLedgers(
        getTabs: _getTabs,
        getLedger: _getLedger,
      );
      switch (loaded) {
        case PayLaterError(:final failure):
          return PayLaterError(failure);
        case PayLaterSuccess(:final data):
          return PayLaterSuccess(_build(data, _clock().dateOnly));
      }
    } catch (e) {
      developer.log(
        'Failed to build the Pay later overview: $e',
        name: 'GetPayLaterOverview',
      );
      return PayLaterError(
        PayLaterFailure(
          type: PayLaterErrorType.databaseFailure,
          message: 'Failed to load Pay later: $e',
        ),
      );
    }
  }

  PayLaterOverview _build(List<TabLedger> ledgers, DateTime today) {
    final monthStart = DateTime(today.year, today.month);
    final nextMonthStart = DateTime(today.year, today.month + 1);
    bool thisMonth(DateTime date) {
      final day = date.dateOnly;
      return !day.isBefore(monthStart) && day.isBefore(nextMonthStart);
    }

    final owing = <TabLedger>[];
    final active = <TabLedger>[];
    final archived = <TabLedger>[];
    for (final ledger in ledgers) {
      if (PayLaterOverview.hasBalance(ledger)) {
        owing.add(ledger);
      } else if (!ledger.tab.isArchived) {
        active.add(ledger);
      } else {
        archived.add(ledger);
      }
    }
    owing.sort(_byUrgency);
    active.sort(_byName);
    archived.sort(_byName);
    final ordered = [...owing, ...active, ...archived];

    // Totals per currency, in the order currencies first appear.
    final totals = <String, _Totals>{};
    for (final ledger in ordered) {
      final added = [
        for (final line in ledger.purchases)
          if (thisMonth(line.expense.date)) line.expense.amount,
      ];
      final paid = [
        for (final line in ledger.payments)
          if (thisMonth(line.payment.paidDate)) line.payment.amount,
      ];
      final inUse =
          !ledger.tab.isArchived ||
          PayLaterOverview.hasBalance(ledger) ||
          added.isNotEmpty ||
          paid.isNotEmpty;
      if (!inUse) continue;
      final currency = ledger.tab.currency;
      final sums = totals.putIfAbsent(currency, () => _Totals(currency));
      sums.owed += sums.money.toUnits(ledger.owed);
      sums.overdue += sums.money.toUnits(ledger.overdue);
      sums.added += sums.money.sumUnits(added);
      sums.paid += sums.money.sumUnits(paid);
    }

    final upcoming = [
      for (final ledger in ordered)
        if (ledger.owed > 0 && ledger.nextSettleUp != null)
          (ledger.tab, ledger.nextSettleUp!),
    ]..sort((a, b) => a.$2.compareTo(b.$2));

    final purchases = [for (final l in ledgers) ...l.purchases]
      ..sort(_newestPurchaseFirst);
    final payments = [for (final l in ledgers) ...l.payments]
      ..sort(_newestPaymentFirst);

    return PayLaterOverview(
      totals: [for (final sums in totals.values) sums.toTotals()],
      tabs: ordered,
      activeTabCount: ledgers.where((l) => !l.tab.isArchived).length,
      upcoming: upcoming,
      recentPurchases: purchases,
      recentPayments: payments,
      today: today,
    );
  }

  /// Overdue tabs first, then the soonest settle-up day (none last), then
  /// name. Amounts aren't compared: tabs may be in different currencies.
  static int _byUrgency(TabLedger a, TabLedger b) {
    final aOverdue = a.overdue > 0;
    final bOverdue = b.overdue > 0;
    if (aOverdue != bOverdue) return aOverdue ? -1 : 1;
    final aDay = a.nextSettleUp;
    final bDay = b.nextSettleUp;
    if (aDay != null && bDay != null) {
      final byDay = aDay.compareTo(bDay);
      if (byDay != 0) return byDay;
    } else if (aDay != null || bDay != null) {
      return aDay != null ? -1 : 1;
    }
    return _byName(a, b);
  }

  static int _byName(TabLedger a, TabLedger b) {
    final byName = _name(a.tab).compareTo(_name(b.tab));
    return byName != 0 ? byName : a.tab.id.compareTo(b.tab.id);
  }

  static String _name(PayLaterTab tab) => tab.name.toLowerCase();

  /// Purchase date, then time, then created; newest first.
  static int _newestPurchaseFirst(PurchaseLine a, PurchaseLine b) =>
      FifoOrder.purchases(b.expense, a.expense);

  /// Paid date, then created; newest first.
  static int _newestPaymentFirst(PaymentLine a, PaymentLine b) =>
      FifoOrder.payments(b.payment, a.payment);
}

/// Running sums for one currency, in its integer units.
class _Totals {
  final String currency;
  final MoneyMath money;
  int owed = 0;
  int overdue = 0;
  int added = 0;
  int paid = 0;

  _Totals(this.currency) : money = MoneyMath.forCurrency(currency);

  CurrencyTotals toTotals() => CurrencyTotals(
    currency: currency,
    owed: money.toAmount(owed),
    overdue: money.toAmount(overdue),
    addedThisMonth: money.toAmount(added),
    paidThisMonth: money.toAmount(paid),
  );
}
