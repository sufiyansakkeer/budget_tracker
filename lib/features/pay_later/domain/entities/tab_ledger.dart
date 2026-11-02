import 'package:equatable/equatable.dart';

import '../../../expenses/domain/entities/expense_entity.dart';
import 'pay_later_tab.dart';
import 'payment_allocation.dart';
import 'settle_rhythm.dart';
import 'tab_payment.dart';

/// How much of a purchase has been paid.
enum PurchaseStatus { unpaid, partlyPaid, paid }

/// A purchase on a tab with what has been paid on it.
class PurchaseLine extends Equatable {
  final ExpenseEntity expense;

  /// Σ allocations to this purchase.
  final double paid;

  /// Amount − [paid].
  final double owes;
  final PurchaseStatus status;

  /// Null when the tab is on demand.
  final SettlePeriod? period;

  const PurchaseLine({
    required this.expense,
    required this.paid,
    required this.owes,
    required this.status,
    required this.period,
  });

  @override
  List<Object?> get props => [expense, paid, owes, status, period];
}

/// A payment with what it covered and the tab balance as of it.
class PaymentLine extends Equatable {
  final TabPayment payment;

  /// This payment's allocations, oldest purchase first.
  final List<PaymentAllocation> allocations;

  /// Amount − Σ [allocations].
  final double unapplied;

  /// Purchases dated on or before the payment day minus this and every
  /// earlier payment (ordered by paid date, then created). Signed: > 0 owed,
  /// 0 settled, < 0 in credit, as of this payment.
  final double balanceAfter;

  const PaymentLine({
    required this.payment,
    required this.allocations,
    required this.unapplied,
    required this.balanceAfter,
  });

  @override
  List<Object?> get props => [payment, allocations, unapplied, balanceAfter];
}

/// Totals for the purchases in one settle period.
class PeriodSummary extends Equatable {
  final SettlePeriod period;
  final double total;
  final double paid;
  final double owes;

  /// Something still owes and the settle-up day is before today.
  final bool overdue;

  /// Oldest first.
  final List<PurchaseLine> purchases;

  const PeriodSummary({
    required this.period,
    required this.total,
    required this.paid,
    required this.owes,
    required this.overdue,
    required this.purchases,
  });

  @override
  List<Object?> get props => [period, total, paid, owes, overdue, purchases];
}

/// Everything derived about one tab (spec §3 "Derived values", §4).
class TabLedger extends Equatable {
  final PayLaterTab tab;

  /// Oldest first (date, time, created).
  final List<PurchaseLine> purchases;

  /// Oldest first (paid date, created).
  final List<PaymentLine> payments;

  /// Oldest first; empty when the tab is on demand.
  final List<PeriodSummary> periods;

  /// Σ owes over purchases.
  final double owed;

  /// Σ unapplied over payments.
  final double credit;

  /// Σ owes over purchases whose settle-up day is before today.
  final double overdue;

  /// Settle-up day of the current period; null on demand or when a manual
  /// date is needed.
  final DateTime? nextSettleUp;

  /// Σ purchase amounts.
  final double totalAdded;

  /// Σ payment amounts.
  final double totalPaid;

  /// The day (local midnight) every figure above is for: "today" for
  /// overdue, the next settle-up and its wording. Part of equality, so a
  /// reload on a new day is a new ledger even when no figure changed.
  final DateTime asOf;

  const TabLedger({
    required this.tab,
    required this.purchases,
    required this.payments,
    required this.periods,
    required this.owed,
    required this.credit,
    required this.overdue,
    required this.nextSettleUp,
    required this.totalAdded,
    required this.totalPaid,
    required this.asOf,
  });

  /// A manual-date tab whose date has passed (or was never set): show "Set
  /// your next settle-up date".
  bool get needsSettleDate => tab.rhythm is ManualDate && nextSettleUp == null;

  @override
  List<Object?> get props => [
    tab,
    purchases,
    payments,
    periods,
    owed,
    credit,
    overdue,
    nextSettleUp,
    totalAdded,
    totalPaid,
    asOf,
  ];
}
