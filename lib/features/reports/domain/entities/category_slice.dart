import 'package:equatable/equatable.dart';

/// A single category slice used by the pie chart.
class CategorySlice extends Equatable {
  final String categoryId;
  final String categoryName;
  final String colorHex;
  final double amount;
  final double percentage;

  const CategorySlice({
    required this.categoryId,
    required this.categoryName,
    required this.colorHex,
    required this.amount,
    required this.percentage,
  });

  @override
  List<Object?> get props => [
    categoryId,
    categoryName,
    colorHex,
    amount,
    percentage,
  ];
}
