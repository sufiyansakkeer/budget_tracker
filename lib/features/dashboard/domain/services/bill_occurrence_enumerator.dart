import '../../../../core/currency/money_math.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../bills/domain/entities/bill_entity.dart';
import '../../../bills/domain/entities/bill_enums.dart';
import '../../../budget/domain/entities/safe_to_spend/commitment_occurrence.dart';
import '../../../budget/domain/entities/safe_to_spend/currency_excluded_summary.dart';
import '../../../budget/domain/entities/safe_to_spend/unlinked_commitment_summary.dart';
import '../../../budget/domain/services/budget_calculation_service.dart';
import '../entities/bill_commitments.dart';

/// Turns bills into the commitments one budget sets money aside for.
///
/// Pure: no database or clock. Lives in the dashboard feature because it
/// needs both bills and budgets, while the budget-domain engine only sees
/// primitives ([CommitmentOccurrence]).
///
/// Rules:
/// - Only unpaid bills count. A paid one-time bill is done; a recurring bill
///   is advanced on payment, so a paid occurrence is never enumerated. A
///   deleted bill is gone (bills have no "cancelled" state).
/// - Occurrences are the stored due date, then repeated application of the
///   step MarkBillPaid stores ([BillEntity.nextDueDate], recurrence interval
///   honoured), so the k-th date always equals what k payments would store.
/// - A running budget sets aside every occurrence up to its end, including
///   overdue ones from before its start: still owed, paid from this budget.
///   A budget that has not started, or has ended, sets aside only the
///   occurrences inside its period.
/// - A linked bill in another currency is left out and disclosed in
///   [BillCommitments.currencyExcluded].
/// - [BillCommitments.unlinked] discloses bills in the budget's currency
///   with occurrences between today (or the start, if later) and the period
///   end that no budget sets aside: not linked, or linked to a budget that
///   is archived, deleted, or does not contain that occurrence.
class BillOccurrenceEnumerator {
  /// Guard against corrupt data (e.g. a weekly bill overdue for decades).
  static const maxOccurrencesPerBill = 1000;

  const BillOccurrenceEnumerator();

  /// Due dates (time of day stripped) of [bill]'s unpaid occurrences, from
  /// its stored due date up to and including [until]. Empty for a paid bill.
  List<DateTime> dueDatesUntil(BillEntity bill, DateTime until) {
    if (bill.isPaid) return const [];
    final dates = <DateTime>[];
    final recurring =
        bill.isRecurring && bill.recurrenceType != RecurrenceType.none;
    var current = bill.dueDate;
    while (dates.length < maxOccurrencesPerBill) {
      final day = _dateOnly(current);
      if (_daysBetween(until, day) > 0) break;
      dates.add(day);
      if (!recurring) break;
      final next = bill.copyWith(dueDate: current).nextDueDate;
      // A non-positive interval would never advance.
      if (_daysBetween(day, next) <= 0) break;
      current = next;
    }
    return dates;
  }

  /// The commitments [budget] sets aside on [today].
  ///
  /// [budgetsById] should hold every known budget (archived ones included)
  /// so bills linked to another budget can be checked; a missing id is
  /// treated as a deleted budget.
  BillCommitments forBudget({
    required BudgetEntity budget,
    required List<BillEntity> bills,
    required Map<String, BudgetEntity> budgetsById,
    required DateTime today,
  }) {
    final day = _dateOnly(today);
    final start = _dateOnly(budget.startDate);
    final end = _dateOnly(budget.endDate);
    final running = budget.isActiveOn(day);
    final budgetMoney = MoneyMath.forCurrency(budget.currency);

    final occurrences = <CommitmentOccurrence>[];
    final excludedUnits = <String, int>{};
    var excludedCount = 0;
    var unlinkedCount = 0;
    var unlinkedUnits = 0;

    final disclosureFrom = _disclosureFrom(start, day);

    for (final bill in bills) {
      if (bill.isPaid) continue;
      final dates = dueDatesUntil(bill, end);
      if (dates.isEmpty) continue;

      if (bill.budgetId == budget.id) {
        final deducted = running
            ? dates
            : dates.where((d) => _daysBetween(start, d) >= 0).toList();
        if (deducted.isEmpty) continue;
        if (bill.currency != budget.currency) {
          final money = MoneyMath.forCurrency(bill.currency);
          excludedCount++;
          excludedUnits[bill.currency] =
              (excludedUnits[bill.currency] ?? 0) +
              money.toUnits(bill.amount) * deducted.length;
          continue;
        }
        for (final d in deducted) {
          occurrences.add(
            CommitmentOccurrence(
              billId: bill.id,
              title: bill.title,
              amount: bill.amount,
              dueDate: d,
              isOverdue: _daysBetween(d, day) > 0,
            ),
          );
        }
        continue;
      }

      if (bill.currency != budget.currency) continue;
      final notSetAside = _notSetAside(
        bill,
        dates,
        budgetsById,
        from: disclosureFrom,
        today: day,
      );
      if (notSetAside.isEmpty) continue;
      unlinkedCount++;
      unlinkedUnits += budgetMoney.toUnits(bill.amount) * notSetAside.length;
    }

    return BillCommitments(
      occurrences: List.unmodifiable(occurrences),
      currencyExcluded: excludedCount == 0
          ? CurrencyExcludedSummary.none
          : CurrencyExcludedSummary(
              count: excludedCount,
              totalsByCurrency: Map.unmodifiable({
                for (final e in excludedUnits.entries)
                  e.key: MoneyMath.forCurrency(e.key).toAmount(e.value),
              }),
            ),
      unlinked: unlinkedCount == 0
          ? UnlinkedCommitmentSummary.none
          : UnlinkedCommitmentSummary(
              count: unlinkedCount,
              total: budgetMoney.toAmount(unlinkedUnits),
            ),
    );
  }

  /// The bills not linked to [budget] with an occurrence between today (or
  /// the start, if later) and the period end that no budget sets aside, in
  /// any currency, soonest due first.
  ///
  /// The ones in [budget]'s currency are exactly the bills [forBudget]
  /// counts in [BillCommitments.unlinked]; the "Link bills" sheet offers
  /// those and shows the others as not linkable.
  List<BillEntity> billsNotSetAside({
    required BudgetEntity budget,
    required List<BillEntity> bills,
    required Map<String, BudgetEntity> budgetsById,
    required DateTime today,
  }) {
    final day = _dateOnly(today);
    final end = _dateOnly(budget.endDate);
    final from = _disclosureFrom(_dateOnly(budget.startDate), day);
    final result = [
      for (final bill in bills)
        if (!bill.isPaid &&
            bill.budgetId != budget.id &&
            _notSetAside(
              bill,
              dueDatesUntil(bill, end),
              budgetsById,
              from: from,
              today: day,
            ).isNotEmpty)
          bill,
    ];
    result.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return result;
  }

  /// Whether [budget] (the one [bill] is linked to) is setting money aside
  /// for the bill's current occurrence (its stored due date) on [today],
  /// so that paying it outside the budget would raise that budget's
  /// safe-to-spend: the bill is unpaid and in the budget's currency, and the
  /// budget is not archived, has not ended, and contains the due date by the
  /// rule [forBudget] deducts with. False for a null budget.
  static bool setsAsideCurrentOccurrence(
    BillEntity bill,
    BudgetEntity? budget,
    DateTime today,
  ) {
    if (bill.isPaid || budget == null) return false;
    if (budget.id != bill.budgetId || budget.currency != bill.currency) {
      return false;
    }
    final day = _dateOnly(today);
    // An ended budget's result ignores bills.
    if (_daysBetween(_dateOnly(budget.endDate), day) > 0) return false;
    return _setsAside(budget, _dateOnly(bill.dueDate), day);
  }

  /// Lower bound for disclosing bills nobody sets aside: from today, but
  /// never before the period.
  static DateTime _disclosureFrom(DateTime start, DateTime today) =>
      _daysBetween(today, start) > 0 ? start : today;

  /// [dates] of [bill] on or after [from] that the budget it is linked to
  /// (if any) does not set aside.
  static Iterable<DateTime> _notSetAside(
    BillEntity bill,
    List<DateTime> dates,
    Map<String, BudgetEntity> budgetsById, {
    required DateTime from,
    required DateTime today,
  }) {
    final linked = bill.budgetId == null ? null : budgetsById[bill.budgetId];
    return dates.where(
      (d) => _daysBetween(from, d) >= 0 && !_setsAside(linked, d, today),
    );
  }

  /// Whether [budget] (the one a bill is linked to) sets [due] aside on
  /// [today], by the same window rule [forBudget] deducts with.
  static bool _setsAside(BudgetEntity? budget, DateTime due, DateTime today) {
    if (budget == null || budget.isArchived) return false;
    final start = _dateOnly(budget.startDate);
    final end = _dateOnly(budget.endDate);
    if (_daysBetween(due, end) < 0) return false;
    return budget.isActiveOn(today) || _daysBetween(start, due) >= 0;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _daysBetween(DateTime from, DateTime to) =>
      BudgetCalculationService.calendarDaysBetween(from, to);
}
