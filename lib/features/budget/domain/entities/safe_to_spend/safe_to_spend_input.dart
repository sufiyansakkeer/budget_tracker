import 'package:equatable/equatable.dart';

import 'commitment_occurrence.dart';
import 'currency_excluded_summary.dart';
import 'safe_to_spend_thresholds.dart';
import 'unlinked_commitment_summary.dart';

/// Everything the safe-to-spend engine needs for one budget on one day.
///
/// All amounts are in [currency]. Spending totals are SQL sums bounded to
/// the budget period; "committed" spending is bill payments recorded against
/// this budget for occurrences it had set aside (expenses with a bill id).
class SafeToSpendInput extends Equatable {
  final String budgetId;
  final String budgetName;
  final String currency;
  final DateTime startDate;
  final DateTime endDate;

  /// The day being evaluated; only its date is used.
  final DateTime today;

  final double budgetAmount;

  /// All spending in the period, including committed bill payments.
  final double periodSpent;

  /// All spending today, including committed bill payments. Ignored when
  /// today is outside the period.
  final double todaySpent;

  /// The part of [periodSpent] that settled set-aside bill occurrences.
  final double committedSpentInPeriod;

  /// The part of [todaySpent] that settled set-aside bill occurrences.
  final double committedSpentToday;

  /// Unpaid bill occurrences to set aside. `null` = bills could not be read
  /// (unavailable), which is different from an empty list (no bills due).
  final List<CommitmentOccurrence>? commitments;

  final CurrencyExcludedSummary currencyExcluded;
  final UnlinkedCommitmentSummary unlinked;

  /// Money kept aside in this budget. `null` = not set.
  final double? reservedAmount;

  /// Money the user wants left at the end of the period. `null` = not set.
  final double? savingsTarget;

  final SafeToSpendThresholds thresholds;

  const SafeToSpendInput({
    required this.budgetId,
    required this.budgetName,
    required this.currency,
    required this.startDate,
    required this.endDate,
    required this.today,
    required this.budgetAmount,
    required this.periodSpent,
    required this.todaySpent,
    this.committedSpentInPeriod = 0,
    this.committedSpentToday = 0,
    required this.commitments,
    this.currencyExcluded = CurrencyExcludedSummary.none,
    this.unlinked = UnlinkedCommitmentSummary.none,
    this.reservedAmount,
    this.savingsTarget,
    this.thresholds = const SafeToSpendThresholds(),
  });

  @override
  List<Object?> get props => [
    budgetId,
    budgetName,
    currency,
    startDate,
    endDate,
    today,
    budgetAmount,
    periodSpent,
    todaySpent,
    committedSpentInPeriod,
    committedSpentToday,
    commitments,
    currencyExcluded,
    unlinked,
    reservedAmount,
    savingsTarget,
    thresholds,
  ];
}
