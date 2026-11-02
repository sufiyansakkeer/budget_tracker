import 'package:equatable/equatable.dart';

import 'pay_later_tab.dart';
import 'tab_ledger.dart';

/// One currency's Pay later figures. Amounts in different currencies are
/// never added together, so the overview holds one of these per currency.
class CurrencyTotals extends Equatable {
  final String currency;

  /// Σ owed over every tab in [currency], archived ones included.
  final double owed;

  /// Σ overdue over every tab in [currency].
  final double overdue;

  /// Σ purchases dated in the current calendar month.
  final double addedThisMonth;

  /// Σ payments that changed hands in the current calendar month.
  final double paidThisMonth;

  const CurrencyTotals({
    required this.currency,
    required this.owed,
    required this.overdue,
    required this.addedThisMonth,
    required this.paidThisMonth,
  });

  @override
  List<Object?> get props => [
    currency,
    owed,
    overdue,
    addedThisMonth,
    paidThisMonth,
  ];
}

/// Everything the Pay later overview shows (spec §7).
class PayLaterOverview extends Equatable {
  /// One entry per currency that has a tab in use (not archived, or with a
  /// balance, or with activity this month), in the order the currencies
  /// first appear in [tabs], so the most pressing currency comes first.
  final List<CurrencyTotals> totals;

  /// Every tab: those with a balance or credit first (archived ones
  /// included, so debt is never hidden), then other active tabs, then
  /// archived tabs with nothing outstanding.
  final List<TabLedger> tabs;

  /// Tabs that aren't archived.
  final int activeTabCount;

  /// Tabs that owe and have a settle-up day, soonest first.
  final List<(PayLaterTab, DateTime)> upcoming;

  /// Every purchase on every tab, newest first.
  final List<PurchaseLine> recentPurchases;

  /// Every payment on every tab, newest first.
  final List<PaymentLine> recentPayments;

  /// The day (local midnight) the overview is for. Part of equality, so a
  /// reload on a new day always reaches the screen ("tomorrow" turns into
  /// "today" even when no figure changed).
  final DateTime today;

  const PayLaterOverview({
    required this.totals,
    required this.tabs,
    required this.activeTabCount,
    required this.upcoming,
    required this.recentPurchases,
    required this.recentPayments,
    required this.today,
  });

  /// No tab at all, archived or not.
  bool get isEmpty => tabs.isEmpty;

  /// The tab [expenseId] is a purchase on.
  PayLaterTab? tabForPurchase(String expenseId) {
    for (final ledger in tabs) {
      for (final line in ledger.purchases) {
        if (line.expense.id == expenseId) return ledger.tab;
      }
    }
    return null;
  }

  /// The tab [line] was paid to.
  PayLaterTab? tabForPayment(PaymentLine line) {
    for (final ledger in tabs) {
      if (ledger.tab.id == line.payment.tabId) return ledger.tab;
    }
    return null;
  }

  /// A tab owes something or holds credit.
  static bool hasBalance(TabLedger ledger) =>
      ledger.owed > 0 || ledger.credit > 0;

  @override
  List<Object?> get props => [
    totals,
    tabs,
    activeTabCount,
    upcoming,
    recentPurchases,
    recentPayments,
    today,
  ];
}

/// One calendar month of a currency's tabs.
class MonthPoint extends Equatable {
  /// First day of the month, local midnight.
  final DateTime month;

  /// Σ purchases dated in the month.
  final double added;

  /// Σ payments that changed hands in the month.
  final double paid;

  /// Σ over tabs of what each owed at the month's last day: its purchases
  /// dated up to then minus its payments made up to then, never below zero
  /// (a tab's credit doesn't offset another tab's debt).
  final double owedAtEnd;

  const MonthPoint({
    required this.month,
    required this.added,
    required this.paid,
    required this.owedAtEnd,
  });

  @override
  List<Object?> get props => [month, added, paid, owedAtEnd];
}

/// Charts and breakdowns for one currency, or one tab.
class PayLaterAnalytics extends Equatable {
  final String currency;

  /// The last six calendar months, this one last.
  final List<MonthPoint> months;

  /// Expense category id → Σ purchases in it, all time.
  final Map<String, double> byExpenseCategory;

  /// Tab id → Σ purchases on it, all time; tabs with none are left out.
  final Map<String, double> byTab;

  /// The tab's settle periods, oldest first; empty unless one tab was
  /// asked for.
  final List<PeriodSummary> periodComparison;

  const PayLaterAnalytics({
    required this.currency,
    required this.months,
    required this.byExpenseCategory,
    required this.byTab,
    required this.periodComparison,
  });

  @override
  List<Object?> get props => [
    currency,
    months,
    byExpenseCategory,
    byTab,
    periodComparison,
  ];
}
