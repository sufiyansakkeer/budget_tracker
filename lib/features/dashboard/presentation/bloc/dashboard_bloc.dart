import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../budget/domain/entities/budget_error.dart';
import '../../../budget/domain/usecases/get_budget_summary_usecase.dart';
import '../../../expenses/presentation/bloc/expense_refresh_bus.dart';
import '../../domain/usecases/get_recent_expenses_usecase.dart';
import '../../domain/usecases/get_smart_insights_usecase.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final GetBudgetSummaryUseCase getBudgetSummaryUseCase;
  final GetRecentExpensesUseCase getRecentExpensesUseCase;
  final GetSmartInsightsUseCase getSmartInsightsUseCase;

  DashboardBloc({
    required this.getBudgetSummaryUseCase,
    required this.getRecentExpensesUseCase,
    required this.getSmartInsightsUseCase,
  }) : super(const DashboardInitial()) {
    on<DashboardLoadData>(_onLoadData);
    on<DashboardRefresh>(_onRefresh);

    // Auto-refresh when expenses change (created, updated, or deleted).
    _refreshSubscription = ExpenseRefreshBus.instance.changes.listen((_) {
      if (!isClosed) {
        add(const DashboardRefresh());
      }
    });
  }

  StreamSubscription<void>? _refreshSubscription;

  @override
  Future<void> close() {
    _refreshSubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoadData(
    DashboardLoadData event,
    Emitter<DashboardState> emit,
  ) async {
    emit(const DashboardLoading());

    final budgetResult = await getBudgetSummaryUseCase();

    switch (budgetResult) {
      case BudgetError(:final failure):
        emit(_resolveErrorState(failure));
        return;

      case BudgetSuccess(:final data):
        final recentExpenses = await getRecentExpensesUseCase();
        final insights = getSmartInsightsUseCase(data);

        emit(
          DashboardLoaded(
            budgetSummary: data,
            recentExpenses: recentExpenses,
            insights: insights,
          ),
        );
    }
  }

  Future<void> _onRefresh(
    DashboardRefresh event,
    Emitter<DashboardState> emit,
  ) async {
    emit(const DashboardLoading());

    final budgetResult = await getBudgetSummaryUseCase();

    switch (budgetResult) {
      case BudgetError(:final failure):
        emit(_resolveErrorState(failure));
        return;

      case BudgetSuccess(:final data):
        final recentExpenses = await getRecentExpensesUseCase();
        final insights = getSmartInsightsUseCase(data);

        emit(
          DashboardLoaded(
            budgetSummary: data,
            recentExpenses: recentExpenses,
            insights: insights,
          ),
        );
    }
  }

  DashboardState _resolveErrorState(BudgetFailure failure) {
    if (failure.type == BudgetErrorType.notFound) {
      return const DashboardEmpty();
    }
    return DashboardError(message: failure.message);
  }
}
