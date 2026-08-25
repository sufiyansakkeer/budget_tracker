import 'package:equatable/equatable.dart';

import '../../../budget/domain/entities/budget_summary_entity.dart';
import '../../../bills/domain/entities/bill_entity.dart';
import '../../domain/entities/recent_expense_entity.dart';
import '../../domain/entities/smart_insight_entity.dart';

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

  const DashboardLoaded({
    required this.budgetSummary,
    required this.recentExpenses,
    required this.insights,
    this.upcomingBills = const [],
  });

  @override
  List<Object?> get props => [
    budgetSummary,
    recentExpenses,
    insights,
    upcomingBills,
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
