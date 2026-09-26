import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/budget_error.dart';
import '../../domain/repository/budget_repository.dart';
import '../../domain/usecases/get_budget_analytics_usecase.dart';
import '../../domain/usecases/get_budget_summary_usecase.dart';
import '../../domain/services/budget_calculation_service.dart';
import '../../../../core/events/refresh_bus.dart';
import 'budget_event.dart';
import 'budget_state.dart';

/// Lightweight event bus for budget switching notifications.
class BudgetBloc extends Bloc<BudgetEvent, BudgetState> {
  final GetBudgetSummaryUseCase getBudgetSummaryUseCase;
  final GetBudgetAnalyticsUseCase getBudgetAnalyticsUseCase;
  final BudgetCalculationService calculationService;
  final BudgetRepository budgetRepository;

  BudgetBloc({
    required this.getBudgetSummaryUseCase,
    required this.getBudgetAnalyticsUseCase,
    required this.calculationService,
    required this.budgetRepository,
  }) : super(const BudgetState()) {
    on<BudgetLoadSummaryEvent>(_onLoadSummary);
    on<BudgetRefreshEvent>(_onRefresh);
    on<BudgetRecalculateEvent>(_onRecalculate);
    on<BudgetSwitchEvent>(_onSwitch);

    // Recalculate budget when expenses change so the engine stays in sync.
    _refreshSubscription = RefreshBuses.expenses.changes.listen((_) {
      if (!isClosed) {
        add(const BudgetRecalculateEvent());
      }
    });

    // Listen for budget switches from other BLoCs.
    _budgetSwitchSubscription = RefreshBuses.budgets.changes.listen((_) {
      if (!isClosed) {
        add(const BudgetRecalculateEvent());
      }
    });

    // Load budget data on creation.
    add(const BudgetLoadSummaryEvent());
  }

  StreamSubscription<void>? _refreshSubscription;
  StreamSubscription<void>? _budgetSwitchSubscription;

  @override
  Future<void> close() {
    _refreshSubscription?.cancel();
    _budgetSwitchSubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoadSummary(
    BudgetLoadSummaryEvent event,
    Emitter<BudgetState> emit,
  ) async {
    await _loadBudgetData(emit);
  }

  Future<void> _onRefresh(
    BudgetRefreshEvent event,
    Emitter<BudgetState> emit,
  ) async {
    calculationService.clearCache();
    await _loadBudgetData(emit);
  }

  Future<void> _onRecalculate(
    BudgetRecalculateEvent event,
    Emitter<BudgetState> emit,
  ) async {
    calculationService.clearCache();
    await _loadBudgetData(emit, showLoading: false);
  }

  Future<void> _onSwitch(
    BudgetSwitchEvent event,
    Emitter<BudgetState> emit,
  ) async {
    emit(state.copyWith(status: BudgetBlocStatus.loading, clearError: true));
    await budgetRepository.setActiveBudgetId(event.budgetId);
    RefreshBuses.budgets.notifyChanged();
    await _loadBudgetData(emit);
  }

  Future<void> _loadBudgetData(
    Emitter<BudgetState> emit, {
    bool showLoading = true,
  }) async {
    if (showLoading) {
      emit(state.copyWith(status: BudgetBlocStatus.loading, clearError: true));
    }

    try {
      await _loadBudgetDataOrThrow(emit);
    } catch (error, stackTrace) {
      // Surface storage failures as an error state instead of an unhandled
      // exception that leaves the screen loading with no message.
      developer.log(
        '[Budget] Failed to load budget data',
        name: 'Budget',
        error: error,
        stackTrace: stackTrace,
      );
      emit(
        state.copyWith(
          status: BudgetBlocStatus.error,
          errorMessage: 'Could not load the budget: $error',
          clearSummary: true,
          clearAnalytics: true,
        ),
      );
    }
  }

  Future<void> _loadBudgetDataOrThrow(Emitter<BudgetState> emit) async {
    final activeId = await budgetRepository.getActiveBudgetId();
    if (activeId == null) {
      emit(
        state.copyWith(
          status: BudgetBlocStatus.error,
          errorMessage: 'No active budget',
          clearSummary: true,
          clearAnalytics: true,
        ),
      );
      return;
    }

    final summaryResult = await getBudgetSummaryUseCase(budgetId: activeId);
    final analyticsResult = await getBudgetAnalyticsUseCase(budgetId: activeId);

    if (summaryResult case BudgetError(:final failure)) {
      emit(
        state.copyWith(
          status: BudgetBlocStatus.error,
          errorMessage: failure.message,
          clearSummary: true,
          clearAnalytics: true,
        ),
      );
      return;
    }

    if (analyticsResult case BudgetError(:final failure)) {
      emit(
        state.copyWith(
          status: BudgetBlocStatus.error,
          errorMessage: failure.message,
          clearSummary: true,
          clearAnalytics: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: BudgetBlocStatus.loaded,
        summary: (summaryResult as BudgetSuccess).data,
        analytics: (analyticsResult as BudgetSuccess).data,
        clearError: true,
      ),
    );
  }
}
