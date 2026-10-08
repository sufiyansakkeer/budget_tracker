import 'package:monivo/features/budget/domain/entities/budget_status.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/commitment_occurrence.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/currency_excluded_summary.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_input.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/unlinked_commitment_summary.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/budget/domain/services/safe_to_spend_calculator.dart';
import 'package:monivo/features/dashboard/domain/entities/budget_daily_limit_entity.dart';
import 'package:monivo/features/dashboard/domain/entities/spending_target_status.dart';

/// Fixed fixture day: 10 Aug 2026 in an Aug 1–31 budget, so 22 days remain
/// (today included) and 9 days are complete.
final fixtureToday = DateTime(2026, 8, 10);

/// A real engine result for widget tests (no hand-built figures), from the
/// same calculator production uses.
SafeToSpendEntity safeToSpend({
  String budgetId = 'b1',
  String name = 'Groceries',
  String currency = 'INR',
  DateTime? today,
  DateTime? start,
  DateTime? end,
  double amount = 22000,
  double periodSpent = 0,
  double todaySpent = 0,
  double committedInPeriod = 0,
  double committedToday = 0,
  List<CommitmentOccurrence> commitments = const [],
  bool billsUnavailable = false,
  UnlinkedCommitmentSummary unlinked = UnlinkedCommitmentSummary.none,
  CurrencyExcludedSummary currencyExcluded = CurrencyExcludedSummary.none,
  double? reserved,
  double? savings,
}) {
  return SafeToSpendCalculator(BudgetCalculationService()).calculate(
    SafeToSpendInput(
      budgetId: budgetId,
      budgetName: name,
      currency: currency,
      startDate: start ?? DateTime(2026, 8, 1),
      endDate: end ?? DateTime(2026, 8, 31),
      today: today ?? fixtureToday,
      budgetAmount: amount,
      periodSpent: periodSpent,
      todaySpent: todaySpent,
      committedSpentInPeriod: committedInPeriod,
      committedSpentToday: committedToday,
      commitments: billsUnavailable ? null : commitments,
      unlinked: unlinked,
      currencyExcluded: currencyExcluded,
      reservedAmount: reserved,
      savingsTarget: savings,
    ),
  );
}

CommitmentOccurrence bill(
  String id,
  double amount,
  DateTime due, {
  String? title,
  bool overdue = false,
}) => CommitmentOccurrence(
  billId: id,
  title: title ?? id,
  amount: amount,
  dueDate: due,
  isOverdue: overdue,
);

/// The daily-limit entry `GetSpendingTargetsUseCase.callPerBudget` builds
/// around [entity] (legacy weekly fields set, to prove they are not shown).
BudgetDailyLimitEntity limitFor(SafeToSpendEntity entity) =>
    BudgetDailyLimitEntity(
      budgetId: entity.budgetId,
      budgetName: entity.budgetName,
      dailyLimit: entity.dailySafeToSpend,
      spentToday: entity.todayDiscretionary,
      remainingToday: entity.remainingToday,
      exceededToday: entity.overToday,
      progress: 0,
      isOverLimit: entity.overToday > 0,
      status: SpendingTargetStatus.onTrack,
      budgetStatus: BudgetStatus.underBudget,
      budgetUtilization: 0,
      monthlyAmount: entity.budgetAmount,
      totalSpent: entity.periodSpent,
      remainingBudget: entity.availableBalance,
      remainingDays: entity.remainingDays,
      weeklyTarget: 7000,
      weeklySpent: 3000,
      weeklyRemaining: 4000,
      weeklyExceeded: 0,
      weeklyProgress: 3000 / 7000,
      weeklyStatus: SpendingTargetStatus.onTrack,
      currency: entity.currency,
      startDate: entity.startDate,
      endDate: entity.endDate,
      safeToSpend: entity,
    );

/// One engine result per running status, from the fixture day.
final runningStatusFixtures = {
  // 22,000 over 22 days, nothing spent: 1,000 a day.
  'onTrack': () => safeToSpend(),
  // 900 of 1,000 spent today (≥ 80%).
  'spendingCarefully': () => safeToSpend(periodSpent: 900, todaySpent: 900),
  // 1,400 spent today: 400 over.
  'overDailyAllowance': () => safeToSpend(periodSpent: 1400, todaySpent: 1400),
  // 1,000 a day over 9 days, with 2,200 of bills: free money runs out.
  'budgetAtRisk': () => safeToSpend(
    amount: 31000,
    periodSpent: 9000,
    commitments: [bill('rent', 2200, DateTime(2026, 8, 25))],
  ),
  // Bills of 25,000 against 22,000 left.
  'overcommitted': () =>
      safeToSpend(commitments: [bill('rent', 25000, DateTime(2026, 8, 25))]),
  // 23,000 spent of 22,000.
  'overBudget': () => safeToSpend(periodSpent: 23000),
};
