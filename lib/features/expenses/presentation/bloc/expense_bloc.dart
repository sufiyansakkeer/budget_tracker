import 'package:flutter_bloc/flutter_bloc.dart';

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

  ExpenseBloc({
    required this.createExpenseUseCase,
    required this.updateExpenseUseCase,
    required this.deleteExpenseUseCase,
    required this.getExpenseByIdUseCase,
    required this.getExpensesUseCase,
    required this.getCategoriesUseCase,
    required this.repository,
  }) : super(const ExpenseState()) {
    on<ExpenseLoadCategories>(_onLoadCategories);
    on<ExpenseLoadById>(_onLoadById);
    on<ExpenseLoadAll>(_onLoadAll);
    on<ExpenseCreate>(_onCreate);
    on<ExpenseUpdate>(_onUpdate);
    on<ExpenseDelete>(_onDelete);
    on<ExpenseClearMessage>(_onClearMessage);
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

  Future<void> _onLoadById(
    ExpenseLoadById event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(state.copyWith(status: ExpenseBlocStatus.loading));

    final result = await getExpenseByIdUseCase(event.id);
    switch (result) {
      case ExpenseSuccess(:final data):
        emit(state.copyWith(status: ExpenseBlocStatus.loaded, expense: data));
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

    final result = await getExpensesUseCase();
    switch (result) {
      case ExpenseSuccess(:final data):
        emit(state.copyWith(status: ExpenseBlocStatus.loaded, expenses: data));
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

    final result = await createExpenseUseCase(event.expense);
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
