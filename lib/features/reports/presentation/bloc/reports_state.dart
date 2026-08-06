import 'package:equatable/equatable.dart';

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
  ];
}
