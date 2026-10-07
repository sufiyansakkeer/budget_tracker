import 'package:equatable/equatable.dart';

/// Tunable limits the safe-to-spend engine uses to pick a status and to
/// decide when the forecast has enough history.
class SafeToSpendThresholds extends Equatable {
  /// Share of today's safe amount (0–1) at which today's discretionary
  /// spending makes the status "Spend carefully".
  final double carefulDailyRatio;

  /// The forecast margin, as a share of the money spendable at the start of
  /// today, below which the status becomes "Spend carefully".
  final double carefulMarginRatio;

  /// Completed days (before today) needed before the forecast is reliable.
  final int minForecastDays;

  const SafeToSpendThresholds({
    this.carefulDailyRatio = 0.8,
    this.carefulMarginRatio = 0.10,
    this.minForecastDays = 3,
  }) : assert(carefulDailyRatio > 0 && carefulDailyRatio <= 1),
       assert(carefulMarginRatio >= 0),
       assert(minForecastDays >= 1);

  @override
  List<Object?> get props => [
    carefulDailyRatio,
    carefulMarginRatio,
    minForecastDays,
  ];
}
