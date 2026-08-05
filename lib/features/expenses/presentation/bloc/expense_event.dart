import 'package:equatable/equatable.dart';

import '../../domain/entities/expense_entity.dart';

abstract class ExpenseEvent extends Equatable {
  const ExpenseEvent();

  @override
  List<Object?> get props => [];
}

/// Loads categories when the form screen opens.
class ExpenseLoadCategories extends ExpenseEvent {
  const ExpenseLoadCategories();
}

/// Loads a single expense by id (for edit/details).
class ExpenseLoadById extends ExpenseEvent {
  final String id;

  const ExpenseLoadById(this.id);

  @override
  List<Object?> get props => [id];
}

/// Loads all expenses (for the list screen).
class ExpenseLoadAll extends ExpenseEvent {
  const ExpenseLoadAll();
}

/// Creates a new expense.
class ExpenseCreate extends ExpenseEvent {
  final ExpenseEntity expense;

  const ExpenseCreate(this.expense);

  @override
  List<Object?> get props => [expense];
}

/// Updates an existing expense.
class ExpenseUpdate extends ExpenseEvent {
  final ExpenseEntity expense;

  const ExpenseUpdate(this.expense);

  @override
  List<Object?> get props => [expense];
}

/// Deletes an expense by id.
class ExpenseDelete extends ExpenseEvent {
  final String id;

  const ExpenseDelete(this.id);

  @override
  List<Object?> get props => [id];
}

/// Clears transient messages (e.g. after a snackbar is shown).
class ExpenseClearMessage extends ExpenseEvent {
  const ExpenseClearMessage();
}
