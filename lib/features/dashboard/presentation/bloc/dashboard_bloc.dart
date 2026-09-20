import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../budget/domain/entities/budget_error.dart';
import '../../../budget/domain/repository/budget_repository.dart';
import '../../../budget/domain/usecases/get_budget_summary_usecase.dart';
import '../../../bills/domain/entities/bill_entity.dart';
import '../../../bills/domain/repository/bill_repository.dart';
import '../../domain/entities/budget_daily_limit_entity.dart';
import '../../domain/entities/spending_target_entity.dart';
import '../../domain/entities/spending_target_status.dart';
import '../../domain/usecases/get_recent_expenses_usecase.dart';
import '../../domain/usecases/get_smart_insights_usecase.dart';
import '../../domain/usecases/get_spending_targets_usecase.dart';
import '../../../../core/events/refresh_bus.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final GetBudgetSummaryUseCase getBudgetSummaryUseCase;
  final GetRecentExpensesUseCase getRecentExpensesUseCase;
  final GetSmartInsightsUseCase getSmartInsightsUseCase;
  final GetSpendingTargetsUseCase getSpendingTargetsUseCase;
  final BudgetRepository budgetRepository;
  final BillRepository billRepository;

  DashboardBloc({
    required this.getBudgetSummaryUseCase,
    required this.getRecentExpensesUseCase,
    required this.getSmartInsightsUseCase,
    required this.getSpendingTargetsUseCase,
    required this.budgetRepository,
    required this.billRepository,
  }) : super(const DashboardInitial()) {
    on<DashboardLoadData>(_onLoadData);
    on<DashboardRefresh>(_onRefresh);

    // Auto-refresh when expenses change (created, updated, or deleted).
    _refreshSubscription = RefreshBuses.expenses.changes.listen((_) {
      if (!isClosed) {
        add(const DashboardRefresh());
      }
    });

    _budgetSwitchSubscription = RefreshBuses.budgets.changes.listen((_) {
      if (!isClosed) {
        add(const DashboardRefresh());
      }
    });

    _billRefreshSubscription = RefreshBuses.bills.changes.listen((_) {
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
    // Keep the current content on screen while refreshing so the dashboard
    // never flashes back to a skeleton after adding an expense. Only the
    // first load shows the skeleton.
    if (state is! DashboardLoaded) {
      emit(const DashboardLoading());
    }
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
          // Soonest first, straight from the due-date index.
          upcomingBills = await billRepository.getUpcomingBills();
        } catch (_) {
          // Bills unavailable — not critical for dashboard.
        }

        // Load per-budget daily spending limits (primary data source).
        List<BudgetDailyLimitEntity> budgetDailyLimits = [];
        SpendingTargetEntity? spendingTarget;
        try {
          final perBudgetResult = await getSpendingTargetsUseCase
              .callPerBudget();
          if (perBudgetResult is PerBudgetSpendingTargetSuccess) {
            budgetDailyLimits = perBudgetResult.budgetLimits;
            // Legacy target for the ACTIVE budget only (never combined).
            spendingTarget = _deriveSpendingTarget(perBudgetResult, activeId);
          }
        } catch (_) {
          // Spending targets unavailable — not critical for dashboard.
        }

        final insights = getSmartInsightsUseCase(
          data,
          spendingTarget: spendingTarget,
          budgetDailyLimits: budgetDailyLimits,
        );

        emit(
          DashboardLoaded(
            budgetSummary: data,
            recentExpenses: recentExpenses,
            insights: insights,
            upcomingBills: upcomingBills,
            spendingTarget: spendingTarget,
            budgetDailyLimits: budgetDailyLimits,
            activeBudgetId: activeId,
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

  /// Derives a legacy [SpendingTargetEntity] for the active budget from the
  /// per-budget data. Daily and weekly amounts are never combined across
  /// budgets; if the active budget is not running today, no target is derived.
  SpendingTargetEntity? _deriveSpendingTarget(
    PerBudgetSpendingTargetSuccess result,
    String activeBudgetId,
  ) {
    BudgetDailyLimitEntity? active;
    for (final bl in result.budgetLimits) {
      if (bl.budgetId == activeBudgetId) {
        active = bl;
        break;
      }
    }
    if (active == null) return null;

    final dailySpent = active.spentToday;
    final weeklyTarget = active.weeklyTarget;
    final weeklySpent = active.weeklySpent;
    final dailyTarget = active.dailyLimit;
    final dailyRemaining = (dailyTarget - dailySpent).clamp(
      0.0,
      double.infinity,
    );
    final dailyExceeded = dailySpent > dailyTarget
        ? dailySpent - dailyTarget
        : 0.0;
    final dailyProgress = dailyTarget > 0
        ? (dailySpent / dailyTarget).clamp(0.0, 1.0)
        : 0.0;
    final dailyStatus = _targetStatus(dailySpent, dailyTarget);

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

    return SpendingTargetEntity(
      dailyTarget: dailyTarget,
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
      currency: result.currency,
    );
  }

  SpendingTargetStatus _targetStatus(double spent, double target) {
    if (target <= 0) return SpendingTargetStatus.onTrack;
    final ratio = spent / target;
    if (ratio > 1.0) return SpendingTargetStatus.exceeded;
    if (ratio >= 0.8) return SpendingTargetStatus.nearLimit;
    return SpendingTargetStatus.onTrack;
  }
}
