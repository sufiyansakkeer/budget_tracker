import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../expenses/presentation/bloc/expense_refresh_bus.dart';
import '../../domain/entities/budget_error.dart';
import '../../domain/repository/budget_repository.dart';
import '../../domain/usecases/get_budget_analytics_usecase.dart';
import '../../domain/usecases/get_budget_summary_usecase.dart';
import '../../domain/services/budget_calculation_service.dart';
import 'budget_event.dart';
import 'budget_state.dart';

/// Lightweight event bus for budget switching notifications.
class BudgetRefreshBus {
  BudgetRefreshBus._();
  static final BudgetRefreshBus instance = BudgetRefreshBus._();

  final StreamController<void> _controller = StreamController<void>.broadcast();
  Stream<void> get changes => _controller.stream;

  void notifyChanged() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  void dispose() => _controller.close();
}

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
    _refreshSubscription = ExpenseRefreshBus.instance.changes.listen((_) {
      if (!isClosed) {
        add(const BudgetRecalculateEvent());
      }
    });

    // Listen for budget switches from other BLoCs.
    _budgetSwitchSubscription = BudgetRefreshBus.instance.changes.listen((_) {
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
    BudgetRefreshBus.instance.notifyChanged();
    await _loadBudgetData(emit);
  }

  Future<void> _loadBudgetData(
    Emitter<BudgetState> emit, {
    bool showLoading = true,
  }) async {
    if (showLoading) {
      emit(state.copyWith(status: BudgetBlocStatus.loading, clearError: true));
    }

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
