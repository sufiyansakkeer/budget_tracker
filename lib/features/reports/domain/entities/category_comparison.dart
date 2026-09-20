import 'package:equatable/equatable.dart';

/// How one category's spending in the selected range compares with the
/// equal-length period immediately before it.
class CategoryComparison extends Equatable {
  final String categoryId;
  final String categoryName;
  final String colorHex;
  final double currentAmount;
  final double previousAmount;

  const CategoryComparison({
    required this.categoryId,
    required this.categoryName,
    required this.colorHex,
    required this.currentAmount,
    required this.previousAmount,
  });

  /// Current − previous. Positive means more was spent this period.
  double get difference => currentAmount - previousAmount;

  /// Change relative to the previous period, or null when there was no
  /// previous spending to compare with (a "new" category).
  double? get percentageChange =>
      previousAmount > 0 ? difference / previousAmount * 100 : null;

  bool get isNew => previousAmount <= 0 && currentAmount > 0;

  bool get isGone => currentAmount <= 0 && previousAmount > 0;

  @override
  List<Object?> get props => [
    categoryId,
    categoryName,
    colorHex,
    currentAmount,
    previousAmount,
  ];
}
