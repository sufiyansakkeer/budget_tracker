import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/budget_error.dart';
import '../../domain/usecases/get_budget_analytics_usecase.dart';
import '../../domain/usecases/get_budget_summary_usecase.dart';
import '../../domain/services/budget_calculation_service.dart';
import 'budget_event.dart';
import 'budget_state.dart';

class BudgetBloc extends Bloc<BudgetEvent, BudgetState> {
  final GetBudgetSummaryUseCase getBudgetSummaryUseCase;
  final GetBudgetAnalyticsUseCase getBudgetAnalyticsUseCase;
  final BudgetCalculationService calculationService;

  BudgetBloc({
    required this.getBudgetSummaryUseCase,
    required this.getBudgetAnalyticsUseCase,
    required this.calculationService,
  }) : super(const BudgetState()) {
    on<BudgetLoadSummaryEvent>(_onLoadSummary);
    on<BudgetRefreshEvent>(_onRefresh);
    on<BudgetRecalculateEvent>(_onRecalculate);
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

  Future<void> _loadBudgetData(
    Emitter<BudgetState> emit, {
    bool showLoading = true,
  }) async {
    if (showLoading) {
      emit(state.copyWith(status: BudgetBlocStatus.loading, clearError: true));
    }

    final summaryResult = await getBudgetSummaryUseCase();
    final analyticsResult = await getBudgetAnalyticsUseCase();

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
