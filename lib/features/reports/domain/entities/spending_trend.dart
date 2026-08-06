import 'package:equatable/equatable.dart';

/// Trend indicators for the selected report period.
class SpendingTrend extends Equatable {
  final double dailyAverage;
  final double weeklyAverage;
  final double monthlyAverage;

  /// Spending growth as a ratio relative to the previous comparable period.
  /// Positive means spending increased, negative means it decreased.
  final double growthRate;

  /// How consistent spending is, 0.0 (erratic) to 1.0 (very consistent).
  final double consistencyScore;

  /// True when the recent half of the range is lower than the first half.
  final bool isImproving;

  const SpendingTrend({
    required this.dailyAverage,
    required this.weeklyAverage,
    required this.monthlyAverage,
    required this.growthRate,
    required this.consistencyScore,
    required this.isImproving,
  });

  static const empty = SpendingTrend(
    dailyAverage: 0,
    weeklyAverage: 0,
    monthlyAverage: 0,
    growthRate: 0,
    consistencyScore: 1,
    isImproving: false,
  );

  @override
  List<Object?> get props => [
    dailyAverage,
    weeklyAverage,
    monthlyAverage,
    growthRate,
    consistencyScore,
    isImproving,
  ];
}
