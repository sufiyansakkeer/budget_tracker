import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../budget/domain/repository/budget_repository.dart';
import '../../../budget/presentation/bloc/budget_bloc.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/entities/expense_failure.dart';
import '../../domain/repository/expense_repository.dart';
import '../../domain/usecases/create_expense_usecase.dart';
import '../../domain/usecases/delete_expense_usecase.dart';
import '../../domain/usecases/get_categories_usecase.dart';
import '../../domain/usecases/get_expense_by_id_usecase.dart';
import '../../domain/usecases/get_expenses_usecase.dart';
import '../../domain/usecases/update_expense_usecase.dart';
import 'expense_event.dart';
import 'expense_refresh_bus.dart';
import 'expense_state.dart';

class ExpenseBloc extends Bloc<ExpenseEvent, ExpenseState> {
  final CreateExpenseUseCase createExpenseUseCase;
  final UpdateExpenseUseCase updateExpenseUseCase;
  final DeleteExpenseUseCase deleteExpenseUseCase;
  final GetExpenseByIdUseCase getExpenseByIdUseCase;
  final GetExpensesUseCase getExpensesUseCase;
  final GetCategoriesUseCase getCategoriesUseCase;
  final ExpenseRepository repository;
  final BudgetRepository budgetRepository;

  ExpenseBloc({
    required this.createExpenseUseCase,
    required this.updateExpenseUseCase,
    required this.deleteExpenseUseCase,
    required this.getExpenseByIdUseCase,
    required this.getExpensesUseCase,
    required this.getCategoriesUseCase,
    required this.repository,
    required this.budgetRepository,
  }) : super(const ExpenseState()) {
    on<ExpenseLoadCategories>(_onLoadCategories);
    on<ExpenseInitialize>(_onInitialize);
    on<ExpenseLoadById>(_onLoadById);
    on<ExpenseLoadAll>(_onLoadAll);
    on<ExpenseCreate>(_onCreate);
    on<ExpenseUpdate>(_onUpdate);
    on<ExpenseDelete>(_onDelete);
    on<ExpenseClearMessage>(_onClearMessage);

    // Reload the expenses list when the active budget is switched so the list
    // only shows expenses belonging to the newly active budget.
    _budgetSwitchSubscription = BudgetRefreshBus.instance.changes.listen((_) {
      if (!isClosed) {
        add(const ExpenseLoadAll());
      }
    });
  }

  StreamSubscription<void>? _budgetSwitchSubscription;

  @override
  Future<void> close() {
    _budgetSwitchSubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoadCategories(
    ExpenseLoadCategories event,
    Emitter<ExpenseState> emit,
  ) async {
    if (state.categories.isNotEmpty) return;

    final result = await getCategoriesUseCase();
    switch (result) {
      case ExpenseSuccess(:final data):
        emit(state.copyWith(categories: data));
      case ExpenseError(:final failure):
        emit(state.copyWith(message: failure.message));
    }
  }

  /// Captures the current date/time once (from a single [DateTime.now()] call)
  /// and stores them in state as the Add Expense form's defaults. This avoids
  /// separate `now()` calls that could straddle midnight.
  Future<void> _onInitialize(
    ExpenseInitialize event,
    Emitter<ExpenseState> emit,
  ) async {
    if (state.initialDate != null && state.initialTime != null) return;

    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day);
    emit(state.copyWith(initialDate: date, initialTime: now));
  }

  Future<String?> _resolveActiveBudgetId() async {
    try {
      return await budgetRepository.getActiveBudgetId();
    } catch (_) {
      return null;
    }
  }

  /// Resolves the effective budget id for an expense during creation.
  /// Prefers the expense's own budgetId; otherwise uses the active budget id
  /// (from state, or resolved from the repository).
  Future<ExpenseEntity> _ensureBudgetId(ExpenseEntity expense) async {
    if (expense.budgetId.isNotEmpty) return expense;

    var id = state.activeBudgetId;
    if (id == null || id.isEmpty) {
      id = await _resolveActiveBudgetId();
    }
    if (id == null || id.isEmpty) return expense;

    return expense.copyWith(budgetId: id);
  }

  Future<void> _onLoadById(
    ExpenseLoadById event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(state.copyWith(status: ExpenseBlocStatus.loading));

    final result = await getExpenseByIdUseCase(event.id);
    switch (result) {
      case ExpenseSuccess(:final data):
        emit(
          state.copyWith(
            status: ExpenseBlocStatus.loaded,
            expense: data,
            activeBudgetId: data.budgetId,
          ),
        );
      case ExpenseError(:final failure):
        emit(
          state.copyWith(
            status: ExpenseBlocStatus.error,
            message: failure.message,
          ),
        );
    }
  }

  Future<void> _onLoadAll(
    ExpenseLoadAll event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(state.copyWith(status: ExpenseBlocStatus.loading));

    // Scope the expenses list to the active budget.
    var budgetId = state.activeBudgetId;
    if (budgetId == null || budgetId.isEmpty) {
      budgetId = await _resolveActiveBudgetId();
    }

    final result = await getExpensesUseCase(budgetId: budgetId);
    switch (result) {
      case ExpenseSuccess(:final data):
        emit(
          state.copyWith(
            status: ExpenseBlocStatus.loaded,
            expenses: data,
            activeBudgetId: budgetId,
          ),
        );
      case ExpenseError(:final failure):
        emit(
          state.copyWith(
            status: ExpenseBlocStatus.error,
            message: failure.message,
          ),
        );
    }
  }

  Future<void> _onCreate(
    ExpenseCreate event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(state.copyWith(status: ExpenseBlocStatus.creating));

    final expense = await _ensureBudgetId(event.expense);
    final result = await createExpenseUseCase(expense);
    switch (result) {
      case ExpenseSuccess():
        ExpenseRefreshBus.instance.notifyChanged();
        emit(
          state.copyWith(
            status: ExpenseBlocStatus.success,
            expense: event.expense,
            message: 'Expense added successfully',
          ),
        );
      case ExpenseError(:final failure):
        emit(
          state.copyWith(
            status: ExpenseBlocStatus.error,
            message: failure.message,
          ),
        );
    }
  }

  Future<void> _onUpdate(
    ExpenseUpdate event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(state.copyWith(status: ExpenseBlocStatus.updating));

    final result = await updateExpenseUseCase(event.expense);
    switch (result) {
      case ExpenseSuccess():
        ExpenseRefreshBus.instance.notifyChanged();
        emit(
          state.copyWith(
            status: ExpenseBlocStatus.success,
            expense: event.expense,
            message: 'Expense updated successfully',
          ),
        );
      case ExpenseError(:final failure):
        emit(
          state.copyWith(
            status: ExpenseBlocStatus.error,
            message: failure.message,
          ),
        );
    }
  }

  Future<void> _onDelete(
    ExpenseDelete event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(state.copyWith(status: ExpenseBlocStatus.deleting));

    final result = await deleteExpenseUseCase(event.id);
    switch (result) {
      case ExpenseSuccess():
        ExpenseRefreshBus.instance.notifyChanged();
        emit(
          state.copyWith(
            status: ExpenseBlocStatus.success,
            message: 'Expense deleted successfully',
          ),
        );
      case ExpenseError(:final failure):
        emit(
          state.copyWith(
            status: ExpenseBlocStatus.error,
            message: failure.message,
          ),
        );
    }
  }

  void _onClearMessage(ExpenseClearMessage event, Emitter<ExpenseState> emit) {
    emit(state.copyWith(status: ExpenseBlocStatus.initial, clearMessage: true));
  }
}
