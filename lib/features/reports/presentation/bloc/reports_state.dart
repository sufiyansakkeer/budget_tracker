import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/budget_entity.dart';

import '../../../dashboard/domain/entities/smart_insight_entity.dart';
import '../../../expenses/domain/entities/expense_history_filter.dart';
import '../../domain/entities/report_data.dart';
import '../../domain/entities/report_period.dart';

/// Status of the reports screen.
enum ReportsStatus { initial, loading, loaded, refreshing, error }

/// Immutable state for the ReportsBloc.
class ReportsState extends Equatable {
  final ReportsStatus status;
  final ReportPeriod period;

  /// Custom range start used when [period] is custom.
  final DateTime? customStart;

  /// Custom range end used when [period] is custom.
  final DateTime? customEnd;

  final ExpenseHistoryFilter filter;

  /// Computed report data (null until loaded).
  final ReportData? data;

  /// Generated smart insights (null until loaded).
  final List<SmartInsight>? insights;

  /// True when the report has loaded but contains no matching expenses.
  final bool isEmpty;

  final String? errorMessage;

  /// Whether the report follows the active budget's period ("This budget"),
  /// shown as a custom range from its start to today.
  final bool followsBudget;

  /// The active budget while [followsBudget], for planned versus actual.
  final BudgetEntity? budget;

  /// The active budget, which every report is limited to; null when there
  /// is none or it couldn't be read.
  final BudgetEntity? activeBudget;

  const ReportsState({
    this.status = ReportsStatus.initial,
    this.period = ReportPeriod.thisMonth,
    this.customStart,
    this.customEnd,
    this.filter = const ExpenseHistoryFilter(),
    this.data,
    this.insights,
    this.isEmpty = false,
    this.errorMessage,
    this.followsBudget = false,
    this.budget,
    this.activeBudget,
  });

  ReportsState copyWith({
    ReportsStatus? status,
    ReportPeriod? period,
    DateTime? customStart,
    DateTime? customEnd,
    ExpenseHistoryFilter? filter,
    ReportData? data,
    List<SmartInsight>? insights,
    bool? isEmpty,
    String? errorMessage,
    bool clearError = false,
    bool? followsBudget,
    BudgetEntity? budget,
    bool clearBudget = false,
    BudgetEntity? activeBudget,
    bool clearActiveBudget = false,
  }) {
    return ReportsState(
      status: status ?? this.status,
      period: period ?? this.period,
      customStart: customStart ?? this.customStart,
      customEnd: customEnd ?? this.customEnd,
      filter: filter ?? this.filter,
      data: data ?? this.data,
      insights: insights ?? this.insights,
      isEmpty: isEmpty ?? this.isEmpty,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      followsBudget: followsBudget ?? this.followsBudget,
      budget: clearBudget ? null : (budget ?? this.budget),
      activeBudget: clearActiveBudget
          ? null
          : (activeBudget ?? this.activeBudget),
    );
  }

  @override
  List<Object?> get props => [
    status,
    period,
    customStart,
    customEnd,
    filter,
    data,
    insights,
    isEmpty,
    errorMessage,
    followsBudget,
    budget,
    activeBudget,
  ];
}
