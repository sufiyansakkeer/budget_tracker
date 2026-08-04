import 'package:equatable/equatable.dart';

class BudgetEntity extends Equatable {
  final String id;
  final double monthlyAmount;
  final double remainingAmount;
  final String currency;
  final int month;
  final int year;
  final DateTime createdAt;

  const BudgetEntity({
    required this.id,
    required this.monthlyAmount,
    required this.remainingAmount,
    required this.currency,
    required this.month,
    required this.year,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        monthlyAmount,
        remainingAmount,
        currency,
        month,
        year,
        createdAt,
      ];
}
