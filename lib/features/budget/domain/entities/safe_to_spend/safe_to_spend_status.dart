/// Overall safe-to-spend state of one budget, in precedence order: the
/// engine picks the first that applies.
enum SafeToSpendStatus {
  /// Today is before the budget's start date.
  notStarted,

  /// Today is after the budget's end date.
  periodEnded,

  /// More has been spent than the budget amount.
  overBudget,

  /// Bills and money set aside exceeded what was left at the start of today.
  /// Today's spending alone never causes this status.
  overcommitted,

  /// Today's discretionary spending is above today's safe amount.
  overDailyAllowance,

  /// At the average pace so far, free money runs out before the period ends.
  budgetAtRisk,

  /// Close to a limit, nothing left to spend, or the figure is incomplete
  /// (bills unavailable or in another currency).
  spendingCarefully,

  onTrack,
}
