import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/budget_entity.dart';
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

/// Which mutation produced the latest [ExpenseBlocStatus.success].
enum ExpenseAction { none, created, updated, deleted, restored }

/// Progress of the quick-add sheet's data ([ExpenseLoadQuickAdd]).
enum QuickAddLoad { idle, loading, loaded }

class ExpenseState extends Equatable {
  final ExpenseBlocStatus status;
  final List<ExpenseCategory> categories;
  final ExpenseEntity? expense;
  final List<ExpenseEntity> expenses;
  final String? activeBudgetId;
  final String? message;

  /// The mutation behind the latest success, so the UI can offer the right
  /// follow-up (e.g. "Undo" after a delete).
  final ExpenseAction lastAction;

  /// The expense removed by the latest delete, kept until it is restored or
  /// another mutation happens, so a SnackBar "Undo" can bring it back.
  final ExpenseEntity? lastDeleted;

  /// Default date captured once when the Add Expense form is initialized.
  final DateTime? initialDate;

  /// Default time captured once when the Add Expense form is initialized.
  final DateTime? initialTime;

  /// Quick add: whether its budget and shortcuts have loaded.
  final QuickAddLoad quickAddLoad;

  /// Quick add: the active budget the expense goes to (null when there is
  /// none, or it could not be read).
  final BudgetEntity? quickAddBudget;

  /// Quick add: the category shortcuts, most used first.
  final List<ExpenseCategory> frequentCategories;

  const ExpenseState({
    this.status = ExpenseBlocStatus.initial,
    this.categories = const [],
    this.expense,
    this.expenses = const [],
    this.activeBudgetId,
    this.message,
    this.lastAction = ExpenseAction.none,
    this.lastDeleted,
    this.initialDate,
    this.initialTime,
    this.quickAddLoad = QuickAddLoad.idle,
    this.quickAddBudget,
    this.frequentCategories = const [],
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
    String? activeBudgetId,
    String? message,
    bool clearMessage = false,
    ExpenseAction? lastAction,
    ExpenseEntity? lastDeleted,
    bool clearLastDeleted = false,
    DateTime? initialDate,
    DateTime? initialTime,
    QuickAddLoad? quickAddLoad,
    BudgetEntity? quickAddBudget,
    bool clearQuickAddBudget = false,
    List<ExpenseCategory>? frequentCategories,
  }) {
    return ExpenseState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      expense: clearExpense ? null : (expense ?? this.expense),
      expenses: expenses ?? this.expenses,
      activeBudgetId: activeBudgetId ?? this.activeBudgetId,
      message: clearMessage ? null : (message ?? this.message),
      lastAction: lastAction ?? this.lastAction,
      lastDeleted: clearLastDeleted ? null : (lastDeleted ?? this.lastDeleted),
      initialDate: initialDate ?? this.initialDate,
      initialTime: initialTime ?? this.initialTime,
      quickAddLoad: quickAddLoad ?? this.quickAddLoad,
      quickAddBudget: clearQuickAddBudget
          ? null
          : (quickAddBudget ?? this.quickAddBudget),
      frequentCategories: frequentCategories ?? this.frequentCategories,
    );
  }

  @override
  List<Object?> get props => [
    status,
    categories,
    expense,
    expenses,
    activeBudgetId,
    message,
    lastAction,
    lastDeleted,
    initialDate,
    initialTime,
    quickAddLoad,
    quickAddBudget,
    frequentCategories,
  ];
}
