import 'package:equatable/equatable.dart';

/// Detailed analytics for a single category.
class CategoryAnalytics extends Equatable {
  final String categoryId;
  final String categoryName;
  final String colorHex;
  final double totalAmount;
  final int transactionCount;
  final double averageTransaction;
  final double highestTransaction;
  final double lowestTransaction;
  final double percentageOfTotal;

  const CategoryAnalytics({
    required this.categoryId,
    required this.categoryName,
    required this.colorHex,
    required this.totalAmount,
    required this.transactionCount,
    required this.averageTransaction,
    required this.highestTransaction,
    required this.lowestTransaction,
    required this.percentageOfTotal,
  });

  @override
  List<Object?> get props => [
    categoryId,
    categoryName,
    colorHex,
    totalAmount,
    transactionCount,
    averageTransaction,
    highestTransaction,
    lowestTransaction,
    percentageOfTotal,
  ];
}
