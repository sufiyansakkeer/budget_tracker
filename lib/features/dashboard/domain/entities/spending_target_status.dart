/// Visual spending-target health indicator derived from target utilization.
enum SpendingTargetStatus {
  /// Spending is below the near-limit threshold (default: 80%).
  onTrack,

  /// Spending is between near-limit and over-target thresholds (default: 80–100%).
  nearLimit,

  /// Spending exceeds the target.
  exceeded,
}
