import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../budget/domain/entities/budget_error.dart';
import '../../../budget/domain/repository/budget_repository.dart';
import '../../../budget/domain/usecases/get_budget_summary_usecase.dart';
import '../../../budget/presentation/bloc/budget_bloc.dart';
import '../../../bills/domain/entities/bill_entity.dart';
import '../../../bills/domain/repository/bill_repository.dart';
import '../../../bills/presentation/bloc/bill_refresh_bus.dart';
import '../../../expenses/presentation/bloc/expense_refresh_bus.dart';
import '../../domain/usecases/get_recent_expenses_usecase.dart';
import '../../domain/usecases/get_smart_insights_usecase.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final GetBudgetSummaryUseCase getBudgetSummaryUseCase;
  final GetRecentExpensesUseCase getRecentExpensesUseCase;
  final GetSmartInsightsUseCase getSmartInsightsUseCase;
  final BudgetRepository budgetRepository;
  final BillRepository billRepository;

  DashboardBloc({
    required this.getBudgetSummaryUseCase,
    required this.getRecentExpensesUseCase,
    required this.getSmartInsightsUseCase,
    required this.budgetRepository,
    required this.billRepository,
  }) : super(const DashboardInitial()) {
    on<DashboardLoadData>(_onLoadData);
    on<DashboardRefresh>(_onRefresh);

    // Auto-refresh when expenses change (created, updated, or deleted).
    _refreshSubscription = ExpenseRefreshBus.instance.changes.listen((_) {
      if (!isClosed) {
        add(const DashboardRefresh());
      }
    });

    _budgetSwitchSubscription = BudgetRefreshBus.instance.changes.listen((_) {
      if (!isClosed) {
        add(const DashboardRefresh());
      }
    });

    _billRefreshSubscription = BillRefreshBus.instance.changes.listen((_) {
      if (!isClosed) {
        add(const DashboardRefresh());
      }
    });
  }

  StreamSubscription<void>? _refreshSubscription;
  StreamSubscription<void>? _budgetSwitchSubscription;
  StreamSubscription<void>? _billRefreshSubscription;

  @override
  Future<void> close() {
    _refreshSubscription?.cancel();
    _budgetSwitchSubscription?.cancel();
    _billRefreshSubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoadData(
    DashboardLoadData event,
    Emitter<DashboardState> emit,
  ) async {
    emit(const DashboardLoading());
    await _load(emit);
  }

  Future<void> _onRefresh(
    DashboardRefresh event,
    Emitter<DashboardState> emit,
  ) async {
    emit(const DashboardLoading());
    await _load(emit);
  }

  Future<void> _load(Emitter<DashboardState> emit) async {
    final activeId = await budgetRepository.getActiveBudgetId();
    if (activeId == null) {
      emit(const DashboardEmpty());
      return;
    }

    final budgetResult = await getBudgetSummaryUseCase(budgetId: activeId);

    switch (budgetResult) {
      case BudgetError(:final failure):
        emit(_resolveErrorState(failure));
        return;

      case BudgetSuccess(:final data):
        final recentExpenses = await getRecentExpensesUseCase(
          budgetId: activeId,
        );

        // Load upcoming bills for dashboard summary.
        List<BillEntity> upcomingBills = [];
        try {
          final allBills = await billRepository.getBills();
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          upcomingBills = allBills
              .where((b) => !b.isPaid && !b.dueDate.isBefore(today))
              .take(3)
              .toList();
        } catch (_) {
          // Bills unavailable — not critical for dashboard.
        }

        final insights = getSmartInsightsUseCase(data);

        emit(
          DashboardLoaded(
            budgetSummary: data,
            recentExpenses: recentExpenses,
            insights: insights,
            upcomingBills: upcomingBills,
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
