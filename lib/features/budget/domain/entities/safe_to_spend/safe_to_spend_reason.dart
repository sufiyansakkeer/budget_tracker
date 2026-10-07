import 'package:equatable/equatable.dart';

/// Why today's safe amount is what it is. The engine returns these in hero
/// priority order (most important first); presentation maps each to copy.
///
/// Amounts are in the budget's currency.
sealed class SafeToSpendReason extends Equatable {
  const SafeToSpendReason();

  @override
  List<Object?> get props => const [];
}

/// Bills could not be read, so none are deducted; the amount may be too high.
class BillsUnavailableReason extends SafeToSpendReason {
  const BillsUnavailableReason();
}

/// More than the budget amount has been spent.
class OverBudgetByReason extends SafeToSpendReason {
  final double amount;
  const OverBudgetByReason(this.amount);

  @override
  List<Object?> get props => [amount];
}

/// Bills and money set aside exceeded what was left at the start of today
/// (the status rule, S0 < 0); [amount] is how far they exceed what is left
/// now (the shortfall, −raw), as the breakdown shows it.
class OvercommittedByReason extends SafeToSpendReason {
  final double amount;
  const OvercommittedByReason(this.amount);

  @override
  List<Object?> get props => [amount];
}

/// Today's discretionary spending is [amount] above today's safe amount.
class OverTodayReason extends SafeToSpendReason {
  final double amount;
  const OverTodayReason(this.amount);

  @override
  List<Object?> get props => [amount];
}

/// At [averageDaily] a day the period would end [deficit] short of the
/// money it must keep (bills, kept aside, savings goal).
class AtRiskReason extends SafeToSpendReason {
  final double averageDaily;
  final double deficit;
  const AtRiskReason({required this.averageDaily, required this.deficit});

  @override
  List<Object?> get props => [averageDaily, deficit];
}

/// Upcoming bills in this currency that no budget sets money aside for.
class BillsNotLinkedReason extends SafeToSpendReason {
  final int count;
  final double total;
  const BillsNotLinkedReason({required this.count, required this.total});

  @override
  List<Object?> get props => [count, total];
}

/// Linked bills in another currency, left out of the deduction.
class BillsCurrencyExcludedReason extends SafeToSpendReason {
  final int count;
  final Map<String, double> totalsByCurrency;
  const BillsCurrencyExcludedReason({
    required this.count,
    required this.totalsByCurrency,
  });

  @override
  List<Object?> get props => [count, totalsByCurrency];
}

/// Nothing is free to spend, without being over budget or overcommitted.
class NothingFreeToSpendReason extends SafeToSpendReason {
  const NothingFreeToSpendReason();
}

/// Today's amount is [amount] lower than it would be without the deductions.
class AllowanceReducedReason extends SafeToSpendReason {
  final double amount;
  final double billsTotal;

  /// `null` when not set.
  final double? reserved;

  /// `null` when not set.
  final double? savings;

  const AllowanceReducedReason({
    required this.amount,
    required this.billsTotal,
    required this.reserved,
    required this.savings,
  });

  @override
  List<Object?> get props => [amount, billsTotal, reserved, savings];
}

/// Set-aside bills paid today ([amount]); they don't use today's amount.
class BillPaymentsTodayReason extends SafeToSpendReason {
  final double amount;
  const BillPaymentsTodayReason(this.amount);

  @override
  List<Object?> get props => [amount];
}

/// [count] bill occurrences totalling [total] are set aside; the earliest is
/// due [nextDue].
class BillsDueReason extends SafeToSpendReason {
  final double total;
  final int count;
  final DateTime nextDue;
  const BillsDueReason({
    required this.total,
    required this.count,
    required this.nextDue,
  });

  @override
  List<Object?> get props => [total, count, nextDue];
}

/// Not enough history for a forecast yet.
class ForecastInsufficientReason extends SafeToSpendReason {
  final int daysNeeded;
  final bool hasAnyExpense;
  const ForecastInsufficientReason({
    required this.daysNeeded,
    required this.hasAnyExpense,
  });

  @override
  List<Object?> get props => [daysNeeded, hasAnyExpense];
}
