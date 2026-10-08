import 'package:equatable/equatable.dart';

import '../../../budget/domain/entities/budget_summary_entity.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
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

  /// The active budget is archived (it can still be the active one, and its
  /// period can include today). Archived budgets get no daily figure, so the
  /// hero says so instead of reporting figures that failed to compute.
  final bool activeBudgetArchived;

  const DashboardLoaded({
    required this.budgetSummary,
    required this.recentExpenses,
    required this.insights,
    this.upcomingBills = const [],
    this.spendingTarget,
    this.budgetDailyLimits = const [],
    this.activeBudgetId,
    this.activeBudgetArchived = false,
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

  /// Today's Safe Spending for the active budget (bills, money kept aside
  /// and the savings goal deducted) — the same entity its daily limit was
  /// derived from. Null when the active budget is not running today or the
  /// figures could not be computed.
  SafeToSpendEntity? get activeSafeToSpend => activeBudgetLimit?.safeToSpend;

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
    activeBudgetArchived,
  ];
}

/// The active budget exists but today is outside its period: it has not
/// started yet or has already ended. There is no daily figure; [safeToSpend]
/// carries the engine's not-started / ended result (bills set aside from it,
/// final balance) for the hero area.
class DashboardNotRunning extends DashboardState {
  final String activeBudgetId;
  final SafeToSpendEntity safeToSpend;
  final List<RecentExpenseEntity> recentExpenses;
  final List<BillEntity> upcomingBills;

  /// Daily limits of the other budgets that are running today.
  final List<BudgetDailyLimitEntity> otherBudgetLimits;

  const DashboardNotRunning({
    required this.activeBudgetId,
    required this.safeToSpend,
    this.recentExpenses = const [],
    this.upcomingBills = const [],
    this.otherBudgetLimits = const [],
  });

  @override
  List<Object?> get props => [
    activeBudgetId,
    safeToSpend,
    recentExpenses,
    upcomingBills,
    otherBudgetLimits,
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
