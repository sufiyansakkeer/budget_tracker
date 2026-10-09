import 'package:equatable/equatable.dart';

import 'commitment_occurrence.dart';
import 'currency_excluded_summary.dart';
import 'safe_to_spend_forecast.dart';
import 'safe_to_spend_reason.dart';
import 'safe_to_spend_status.dart';
import 'unlinked_commitment_summary.dart';

/// Safe-to-spend result for one budget on one day, produced by
/// `SafeToSpendCalculator`. Every figure a screen shows comes from here.
///
/// Identity (amounts in [currency]):
/// rawSpendable = availableBalance − upcomingCommitments − reserved
///   − remainingSavingsTarget (signed); freeToSpend = max(0, raw);
/// shortfall = max(0, −raw).
///
/// Amounts are exact (summed in integer units); [dailySafeToSpend] is the
/// unrounded `BudgetCalculationService.calculateTodaySafeSpending` quotient.
/// Display floors "safe" amounts with `CurrencyFormatter.floorForDisplay`.
class SafeToSpendEntity extends Equatable {
  final String budgetId;
  final String budgetName;
  final String currency;
  final DateTime startDate;
  final DateTime endDate;

  /// Date evaluated (time of day stripped).
  final DateTime today;

  final int totalDays;

  /// Days of the period up to and including today (0 before it starts,
  /// [totalDays] after it ends).
  final int daysPassed;

  /// Days left including today (at least 1 while running; [totalDays] before
  /// the start, 0 after the end).
  final int remainingDays;

  /// Days until the period starts (0 unless [status] is notStarted).
  final int daysUntilStart;

  final double budgetAmount;
  final double periodSpent;

  /// A: budget amount − period spending (signed).
  final double availableBalance;

  /// B: total of [commitments] (0 when unavailable).
  final double upcomingCommitments;

  /// Exactly the occurrences deducted in B, deduplicated by (bill, due
  /// date) and sorted by due date. Empty when bills are unavailable.
  final List<CommitmentOccurrence> commitments;

  /// C: money kept aside; `null` = not set (distinct from 0).
  final double? reservedAmount;

  /// The savings goal as set; `null` = not set.
  final double? savingsTarget;

  /// D: savings goal still to keep; `null` = not set. Equals the goal
  /// because savings contributions are not tracked
  /// ([savingsContributionsTracked] is false).
  final double? remainingSavingsTarget;

  final double rawSpendable;
  final double freeToSpend;
  final double shortfall;

  /// Spendable money at the start of today: raw + today's discretionary.
  final double spendableAtStartOfToday;

  final double todaySpent;
  final double committedSpentToday;
  final double committedSpentInPeriod;

  /// Today's spending that is not a set-aside bill payment.
  final double todayDiscretionary;

  /// Today's safe spending; fixed for the whole day; never negative.
  final double dailySafeToSpend;
  final double remainingToday;
  final double overToday;

  /// Today's amount with no bills, kept-aside money or savings goal.
  final double baselineDaily;

  /// baselineDaily − dailySafeToSpend (never negative).
  final double allowanceReduction;

  /// Tomorrow's safe amount if nothing more is spent today and nothing else
  /// changes: raw spendable ÷ the days left after today. `null` on the last
  /// day of the period and outside the running period. Informational: an
  /// estimate the UI labels "about".
  final double? tomorrowIfNoMoreSpending;

  /// When today's discretionary spending is over today's amount, how much
  /// lower each of the days after today is because of it: over today ÷ the
  /// days left after today. `null` when not over, on the last day, or when
  /// tomorrow's amount is already 0 (the spread would overstate the change).
  final double? overTodayPerRemainingDay;

  /// `null` outside the running period.
  final SafeToSpendForecast? forecast;

  final SafeToSpendStatus status;

  /// Most important first (hero priority).
  final List<SafeToSpendReason> reasons;

  final UnlinkedCommitmentSummary unlinked;
  final CurrencyExcludedSummary currencyExcluded;

  /// False when bills could not be read; B is then 0 and labelled as such.
  final bool commitmentsAvailable;

  /// Always false: the app has no savings ledger, so [remainingSavingsTarget]
  /// is the full goal. Documented assumption, never shown as tracked data.
  final bool savingsContributionsTracked;

  const SafeToSpendEntity({
    required this.budgetId,
    required this.budgetName,
    required this.currency,
    required this.startDate,
    required this.endDate,
    required this.today,
    required this.totalDays,
    required this.daysPassed,
    required this.remainingDays,
    required this.daysUntilStart,
    required this.budgetAmount,
    required this.periodSpent,
    required this.availableBalance,
    required this.upcomingCommitments,
    required this.commitments,
    required this.reservedAmount,
    required this.savingsTarget,
    required this.remainingSavingsTarget,
    required this.rawSpendable,
    required this.freeToSpend,
    required this.shortfall,
    required this.spendableAtStartOfToday,
    required this.todaySpent,
    required this.committedSpentToday,
    required this.committedSpentInPeriod,
    required this.todayDiscretionary,
    required this.dailySafeToSpend,
    required this.remainingToday,
    required this.overToday,
    required this.baselineDaily,
    required this.allowanceReduction,
    this.tomorrowIfNoMoreSpending,
    this.overTodayPerRemainingDay,
    required this.forecast,
    required this.status,
    required this.reasons,
    required this.unlinked,
    required this.currencyExcluded,
    required this.commitmentsAvailable,
    this.savingsContributionsTracked = false,
  });

  /// Today is inside the period.
  bool get isRunning =>
      status != SafeToSpendStatus.notStarted &&
      status != SafeToSpendStatus.periodEnded;

  /// The reason the hero explains, if any.
  SafeToSpendReason? get topReason => reasons.isEmpty ? null : reasons.first;

  /// B + C + D: everything deducted from the available balance.
  double get totalDeductions =>
      upcomingCommitments +
      (reservedAmount ?? 0) +
      (remainingSavingsTarget ?? 0);

  @override
  List<Object?> get props => [
    budgetId,
    budgetName,
    currency,
    startDate,
    endDate,
    today,
    totalDays,
    daysPassed,
    remainingDays,
    daysUntilStart,
    budgetAmount,
    periodSpent,
    availableBalance,
    upcomingCommitments,
    commitments,
    reservedAmount,
    savingsTarget,
    remainingSavingsTarget,
    rawSpendable,
    freeToSpend,
    shortfall,
    spendableAtStartOfToday,
    todaySpent,
    committedSpentToday,
    committedSpentInPeriod,
    todayDiscretionary,
    dailySafeToSpend,
    remainingToday,
    overToday,
    baselineDaily,
    allowanceReduction,
    tomorrowIfNoMoreSpending,
    overTodayPerRemainingDay,
    forecast,
    status,
    reasons,
    unlinked,
    currencyExcluded,
    commitmentsAvailable,
    savingsContributionsTracked,
  ];
}
