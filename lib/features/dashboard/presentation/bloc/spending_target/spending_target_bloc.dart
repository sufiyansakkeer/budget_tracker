import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../budget/presentation/bloc/budget_bloc.dart';
import '../../../../expenses/presentation/bloc/expense_refresh_bus.dart';
import '../../../domain/entities/spending_target_entity.dart';
import '../../../domain/entities/spending_target_status.dart';
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

  SpendingTargetBloc({required this.getSpendingTargetsUseCase})
    : super(const SpendingTargetState()) {
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
    emit(
      state.copyWith(
        status: SpendingTargetBlocStatus.loading,
        clearError: true,
      ),
    );
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
    emit(
      state.copyWith(
        status: SpendingTargetBlocStatus.loading,
        clearError: true,
      ),
    );
    await _compute(emit, referenceDate: event.date);
  }

  Future<void> _compute(
    Emitter<SpendingTargetState> emit, {
    DateTime? referenceDate,
  }) async {
    final result = await getSpendingTargetsUseCase.callPerBudget(
      referenceDate: referenceDate,
    );

    switch (result) {
      case PerBudgetSpendingTargetNoBudget():
        emit(
          state.copyWith(
            status: SpendingTargetBlocStatus.empty,
            clearError: true,
          ),
        );
      case PerBudgetSpendingTargetError(:final failure):
        emit(
          state.copyWith(
            status: SpendingTargetBlocStatus.error,
            errorMessage: failure.message,
          ),
        );
      case PerBudgetSpendingTargetSuccess(
        :final budgetLimits,
        :final combinedDailyTarget,
        :final currency,
      ):
        // Derive legacy combined target from per-budget data.
        final dailySpent = budgetLimits.fold<double>(
          0.0,
          (sum, bl) => sum + bl.spentToday,
        );
        final weeklyTarget = budgetLimits.fold<double>(
          0.0,
          (sum, bl) => sum + bl.weeklyTarget,
        );
        final weeklySpent = budgetLimits.fold<double>(
          0.0,
          (sum, bl) => sum + bl.weeklySpent,
        );

        final dailyRemaining = (combinedDailyTarget - dailySpent).clamp(
          0.0,
          double.infinity,
        );
        final dailyExceeded = dailySpent > combinedDailyTarget
            ? dailySpent - combinedDailyTarget
            : 0.0;
        final dailyProgress = combinedDailyTarget > 0
            ? (dailySpent / combinedDailyTarget).clamp(0.0, 1.0)
            : 0.0;
        final dailyStatus = _targetStatus(dailySpent, combinedDailyTarget);

        final weeklyRemaining = (weeklyTarget - weeklySpent).clamp(
          0.0,
          double.infinity,
        );
        final weeklyExceeded = weeklySpent > weeklyTarget
            ? weeklySpent - weeklyTarget
            : 0.0;
        final weeklyProgress = weeklyTarget > 0
            ? (weeklySpent / weeklyTarget).clamp(0.0, 1.0)
            : 0.0;
        final weeklyStatus = _targetStatus(weeklySpent, weeklyTarget);

        emit(
          state.copyWith(
            status: SpendingTargetBlocStatus.loaded,
            targets: SpendingTargetEntity(
              dailyTarget: combinedDailyTarget,
              dailySpent: dailySpent,
              dailyRemaining: dailyRemaining,
              dailyExceeded: dailyExceeded,
              dailyProgress: dailyProgress,
              dailyStatus: dailyStatus,
              weeklyTarget: weeklyTarget,
              weeklySpent: weeklySpent,
              weeklyRemaining: weeklyRemaining,
              weeklyExceeded: weeklyExceeded,
              weeklyProgress: weeklyProgress,
              weeklyStatus: weeklyStatus,
              currency: currency,
            ),
            clearError: true,
          ),
        );
    }
  }

  SpendingTargetStatus _targetStatus(double spent, double target) {
    if (target <= 0) return SpendingTargetStatus.onTrack;
    final ratio = spent / target;
    if (ratio > 1.0) return SpendingTargetStatus.exceeded;
    if (ratio >= 0.8) return SpendingTargetStatus.nearLimit;
    return SpendingTargetStatus.onTrack;
  }
}
