import '../../../../core/currency/money_math.dart';
import '../../../../core/dates/calendar_dates.dart';
import '../../../expenses/domain/entities/expense_entity.dart';
import '../entities/pay_later_tab.dart';
import '../entities/payment_allocation.dart';
import '../entities/settle_rhythm.dart';
import '../entities/tab_ledger.dart';
import '../entities/tab_payment.dart';
import 'settle_schedule.dart';
import 'fifo_order.dart';

/// Derives a [TabLedger] from stored rows (spec §3 "Derived values", §4).
///
/// Pure: works on the allocations as given and never reconciles (the
/// allocator does). Every sum is done once in integer units of the tab's
/// currency ([MoneyMath]) and converted back at the end. An allocation
/// whose payment or purchase is not among the inputs is ignored on both
/// sides, so owed − credit always equals purchases − payments.
abstract final class PayLaterLedger {
  /// Assumes reconciled allocations: no purchase is over-allocated, so every
  /// owes is ≥ 0 (`PayLaterAllocator.reconcile` guarantees this).
  /// Negative owes are not clamped; they would reduce owed and overdue.
  static TabLedger build({
    required PayLaterTab tab,
    required List<ExpenseEntity> purchases,
    required List<TabPayment> payments,
    required List<PaymentAllocation> allocations,
    required DateTime today,
  }) {
    final money = MoneyMath.forCurrency(tab.currency);
    final day = today.dateOnly;

    final orderedPurchases = [...purchases]..sort(_purchaseOrder);
    final orderedPayments = [...payments]..sort(_paymentOrder);
    final purchaseRank = {
      for (var i = 0; i < orderedPurchases.length; i++)
        orderedPurchases[i].id: i,
    };
    final paymentIds = {for (final p in payments) p.id};

    final paidUnits = <String, int>{};
    final appliedUnits = <String, int>{};
    final allocationsByPayment = <String, List<PaymentAllocation>>{};
    for (final allocation in allocations) {
      if (!paymentIds.contains(allocation.paymentId) ||
          !purchaseRank.containsKey(allocation.expenseId)) {
        continue;
      }
      final units = money.toUnits(allocation.amount);
      paidUnits.update(
        allocation.expenseId,
        (v) => v + units,
        ifAbsent: () => units,
      );
      appliedUnits.update(
        allocation.paymentId,
        (v) => v + units,
        ifAbsent: () => units,
      );
      allocationsByPayment
          .putIfAbsent(allocation.paymentId, () => [])
          .add(allocation);
    }

    // Purchases.
    var owedUnits = 0;
    var overdueUnits = 0;
    var addedUnits = 0;
    final lines = <PurchaseLine>[];
    final owesUnitsById = <String, int>{};
    for (final expense in orderedPurchases) {
      final amount = money.toUnits(expense.amount);
      final paid = paidUnits[expense.id] ?? 0;
      final owes = amount - paid;
      final period = SettleSchedule.periodFor(tab.rhythm, expense.date);
      addedUnits += amount;
      owedUnits += owes;
      owesUnitsById[expense.id] = owes;
      if (_isPastSettleUp(period, day)) overdueUnits += owes;
      lines.add(
        PurchaseLine(
          expense: expense,
          paid: money.toAmount(paid),
          owes: money.toAmount(owes),
          status: owes <= 0
              ? PurchaseStatus.paid
              : paid == 0
              ? PurchaseStatus.unpaid
              : PurchaseStatus.partlyPaid,
          period: period,
        ),
      );
    }

    // Payments, with the balance as of each one.
    var creditUnits = 0;
    var paidToDate = 0;
    var paidTotalUnits = 0;
    final paymentLines = <PaymentLine>[];
    for (final payment in orderedPayments) {
      final amount = money.toUnits(payment.amount);
      final unapplied = amount - (appliedUnits[payment.id] ?? 0);
      creditUnits += unapplied;
      paidTotalUnits += amount;
      paidToDate += amount;
      final paidDay = payment.paidDate.dateOnly;
      // A purchase dated on the payment day counts as before it.
      final purchasedToDate = money.sumUnits([
        for (final e in orderedPurchases)
          if (!e.date.dateOnly.isAfter(paidDay)) e.amount,
      ]);
      paymentLines.add(
        PaymentLine(
          payment: payment,
          allocations: [...?allocationsByPayment[payment.id]]
            ..sort(
              (a, b) => purchaseRank[a.expenseId]!.compareTo(
                purchaseRank[b.expenseId]!,
              ),
            ),
          unapplied: money.toAmount(unapplied),
          balanceAfter: money.toAmount(purchasedToDate - paidToDate),
        ),
      );
    }

    // Periods, oldest first.
    final byPeriod = <SettlePeriod, List<PurchaseLine>>{};
    for (final line in lines) {
      final period = line.period;
      if (period == null) continue;
      byPeriod.putIfAbsent(period, () => []).add(line);
    }
    final periods = [
      for (final MapEntry(key: period, value: periodLines) in byPeriod.entries)
        _summary(money, period, periodLines, owesUnitsById, day),
    ]..sort((a, b) => _compareStarts(a.period.start, b.period.start));

    return TabLedger(
      tab: tab,
      purchases: lines,
      payments: paymentLines,
      periods: periods,
      owed: money.toAmount(owedUnits),
      credit: money.toAmount(creditUnits),
      overdue: money.toAmount(overdueUnits),
      nextSettleUp: nextSettleUpDue(tab.rhythm, day, lines, money),
      totalAdded: money.toAmount(addedUnits),
      totalPaid: money.toAmount(paidTotalUnits),
      asOf: day,
    );
  }

  static PeriodSummary _summary(
    MoneyMath money,
    SettlePeriod period,
    List<PurchaseLine> lines,
    Map<String, int> owesUnitsById,
    DateTime today,
  ) {
    final total = money.sumUnits(lines.map((l) => l.expense.amount));
    var owes = 0;
    for (final line in lines) {
      owes += owesUnitsById[line.expense.id]!;
    }
    return PeriodSummary(
      period: period,
      total: money.toAmount(total),
      paid: money.toAmount(total - owes),
      owes: money.toAmount(owes),
      overdue: owes > 0 && _isPastSettleUp(period, today),
      purchases: lines,
    );
  }

  /// The first settle-up day on or after [from] with something to settle:
  /// a day counts only while purchases dated before it still owe. So on a
  /// settle-up day whose period is already paid, a purchase made that day
  /// points at the following settle-up, not "today". Later days always
  /// count while anything is owed; a tab owing nothing keeps the schedule.
  static DateTime? nextSettleUpDue(
    SettleRhythm rhythm,
    DateTime from,
    List<PurchaseLine> purchases,
    MoneyMath money,
  ) {
    var candidate = SettleSchedule.nextSettleUp(rhythm, from);
    while (candidate != null) {
      final settleUp = candidate;
      var dueUnits = 0;
      var laterUnits = 0;
      for (final line in purchases) {
        final owes = money.toUnits(line.owes);
        if (owes <= 0) continue;
        if (line.expense.date.dateOnly.isBefore(settleUp)) {
          dueUnits += owes;
        } else {
          laterUnits += owes;
        }
      }
      if (dueUnits > 0 || laterUnits == 0) return settleUp;
      candidate = SettleSchedule.nextSettleUp(rhythm, settleUp.addDays(1));
    }
    return null;
  }

  /// The period's settle-up day is before [today] (a date). Open periods
  /// and on-demand purchases are never overdue.
  static bool _isPastSettleUp(SettlePeriod? period, DateTime today) {
    final settleUp = period?.settleUp;
    return settleUp != null && settleUp.isBefore(today);
  }

  /// A period with no first day sorts before every other.
  static int _compareStarts(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b ? 0 : (a == null ? -1 : 1);
    return a.compareTo(b);
  }

  /// FIFO ([FifoOrder], shared with `PayLaterAllocator`).
  static int _purchaseOrder(ExpenseEntity a, ExpenseEntity b) =>
      FifoOrder.purchases(a, b);

  static int _paymentOrder(TabPayment a, TabPayment b) =>
      FifoOrder.payments(a, b);
}
