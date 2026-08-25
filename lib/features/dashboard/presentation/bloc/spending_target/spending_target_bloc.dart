import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../budget/presentation/bloc/budget_bloc.dart';
import '../../../../expenses/presentation/bloc/expense_refresh_bus.dart';
import '../../../domain/usecases/get_spending_targets_usecase.dart';
import 'spending_target_event.dart';
import 'spending_target_state.dart';

/// Manages daily and weekly spending targets. Automatically refreshes when
/// expenses are added/edited/deleted or the active budget changes.
class SpendingTargetBloc
    extends Bloc<SpendingTargetEvent, SpendingTargetState> {
  final GetSpendingTargetsUseCase getSpendingTargetsUseCase;

  StreamSubscription<void>? _expenseSubscription;
  StreamSubscription<void>? _budgetSwitchSubscription;

  SpendingTargetBloc({
    required this.getSpendingTargetsUseCase,
  }) : super(const SpendingTargetState()) {
    on<SpendingTargetLoad>(_onLoad);
    on<SpendingTargetRefresh>(_onRefresh);
    on<SpendingTargetDateChanged>(_onDateChanged);

    // Auto-refresh when expenses change.
    _expenseSubscription = ExpenseRefreshBus.instance.changes.listen((_) {
      if (!isClosed) {
        add(const SpendingTargetRefresh());
      }
    });

    // Auto-refresh when active budget is switched.
    _budgetSwitchSubscription = BudgetRefreshBus.instance.changes.listen((_) {
      if (!isClosed) {
        add(const SpendingTargetRefresh());
      }
    });
  }

  @override
  Future<void> close() {
    _expenseSubscription?.cancel();
    _budgetSwitchSubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoad(
    SpendingTargetLoad event,
    Emitter<SpendingTargetState> emit,
  ) async {
    emit(state.copyWith(
      status: SpendingTargetBlocStatus.loading,
      clearError: true,
    ));
    await _compute(emit);
  }

  Future<void> _onRefresh(
    SpendingTargetRefresh event,
    Emitter<SpendingTargetState> emit,
  ) async {
    await _compute(emit);
  }

  Future<void> _onDateChanged(
    SpendingTargetDateChanged event,
    Emitter<SpendingTargetState> emit,
  ) async {
    emit(state.copyWith(
      status: SpendingTargetBlocStatus.loading,
      clearError: true,
    ));
    await _compute(emit, referenceDate: event.date);
  }

  Future<void> _compute(
    Emitter<SpendingTargetState> emit, {
    DateTime? referenceDate,
  }) async {
    final result = await getSpendingTargetsUseCase(referenceDate: referenceDate);

    switch (result) {
      case SpendingTargetNoBudget():
        emit(state.copyWith(
          status: SpendingTargetBlocStatus.empty,
          clearError: true,
        ));
      case SpendingTargetError(:final failure):
        emit(state.copyWith(
          status: SpendingTargetBlocStatus.error,
          errorMessage: failure.message,
        ));
      case SpendingTargetSuccess(:final data):
        emit(state.copyWith(
          status: SpendingTargetBlocStatus.loaded,
          targets: data,
          clearError: true,
        ));
    }
  }
}
