/// Visual budget health indicator derived from spending utilization.
enum BudgetStatus {
  /// Spending is below the near-limit threshold (default: 80%).
  underBudget,

  /// Spending is between near-limit and over-budget thresholds (default: 80–100%).
  nearLimit,

  /// Spending exceeds the budget amount (default: above 100%).
  overBudget,
}
