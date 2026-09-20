import 'package:equatable/equatable.dart';

import '../../../budget/domain/entities/budget_summary_entity.dart';
import '../../../bills/domain/entities/bill_entity.dart';
import '../../domain/entities/budget_daily_limit_entity.dart';
import '../../domain/entities/recent_expense_entity.dart';
import '../../domain/entities/smart_insight_entity.dart';
import '../../domain/entities/spending_target_entity.dart';

abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {
  const DashboardInitial();
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

class DashboardLoaded extends DashboardState {
  final BudgetSummaryEntity budgetSummary;
  final List<RecentExpenseEntity> recentExpenses;
  final List<SmartInsight> insights;
  final List<BillEntity> upcomingBills;

  /// Legacy daily/weekly target for the active budget only (never combined).
  final SpendingTargetEntity? spendingTarget;

  /// Per-budget daily spending limits — one entry per active budget.
  ///
  /// This is the primary data source for the "Today's Safe Spending"
  /// section. Each entry contains independent daily/weekly limits calculated
  /// using only that budget's data.
  final List<BudgetDailyLimitEntity> budgetDailyLimits;

  /// Id of the budget currently selected as active, so the UI can single out
  /// its entry in [budgetDailyLimits].
  final String? activeBudgetId;

  const DashboardLoaded({
    required this.budgetSummary,
    required this.recentExpenses,
    required this.insights,
    this.upcomingBills = const [],
    this.spendingTarget,
    this.budgetDailyLimits = const [],
    this.activeBudgetId,
  });

  /// The daily limit entry belonging to the active budget, if it is running
  /// today.
  BudgetDailyLimitEntity? get activeBudgetLimit {
    if (activeBudgetId == null) return null;
    for (final limit in budgetDailyLimits) {
      if (limit.budgetId == activeBudgetId) return limit;
    }
    return null;
  }

  /// Daily limits for every other budget that is running today.
  List<BudgetDailyLimitEntity> get otherBudgetLimits => budgetDailyLimits
      .where((limit) => limit.budgetId != activeBudgetId)
      .toList();

  @override
  List<Object?> get props => [
    budgetSummary,
    recentExpenses,
    insights,
    upcomingBills,
    spendingTarget,
    budgetDailyLimits,
    activeBudgetId,
  ];
}

class DashboardEmpty extends DashboardState {
  const DashboardEmpty();
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError({required this.message});

  @override
  List<Object?> get props => [message];
}
