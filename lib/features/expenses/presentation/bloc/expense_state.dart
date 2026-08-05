import 'package:equatable/equatable.dart';

import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_entity.dart';

enum ExpenseBlocStatus {
  initial,
  loading,
  loaded,
  creating,
  updating,
  deleting,
  success,
  error,
}

class ExpenseState extends Equatable {
  final ExpenseBlocStatus status;
  final List<ExpenseCategory> categories;
  final ExpenseEntity? expense;
  final List<ExpenseEntity> expenses;
  final String? message;

  const ExpenseState({
    this.status = ExpenseBlocStatus.initial,
    this.categories = const [],
    this.expense,
    this.expenses = const [],
    this.message,
  });

  bool get isBusy =>
      status == ExpenseBlocStatus.creating ||
      status == ExpenseBlocStatus.updating ||
      status == ExpenseBlocStatus.deleting;

  ExpenseState copyWith({
    ExpenseBlocStatus? status,
    List<ExpenseCategory>? categories,
    ExpenseEntity? expense,
    bool clearExpense = false,
    List<ExpenseEntity>? expenses,
    String? message,
    bool clearMessage = false,
  }) {
    return ExpenseState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      expense: clearExpense ? null : (expense ?? this.expense),
      expenses: expenses ?? this.expenses,
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  @override
  List<Object?> get props => [status, categories, expense, expenses, message];
}
