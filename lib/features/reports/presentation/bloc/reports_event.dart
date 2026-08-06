import 'package:equatable/equatable.dart';

import '../../../expenses/domain/entities/expense_history_filter.dart';
import '../../domain/entities/report_period.dart';

/// Events for the ReportsBloc.
abstract class ReportsEvent extends Equatable {
  const ReportsEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the initial report for [period].
class ReportsLoad extends ReportsEvent {
  final ReportPeriod period;
  final ExpenseHistoryFilter filter;

  const ReportsLoad({
    this.period = ReportPeriod.thisMonth,
    this.filter = const ExpenseHistoryFilter(),
  });

  @override
  List<Object?> get props => [period, filter];
}

/// Refreshes the report, preserving the current period and filter.
class ReportsRefresh extends ReportsEvent {
  const ReportsRefresh();

  @override
  List<Object?> get props => [];
}

/// Changes the report period and reloads.
class ReportsPeriodChanged extends ReportsEvent {
  final ReportPeriod period;

  /// Custom date range start (only used when period is custom).
  final DateTime? customStart;

  /// Custom date range end (only used when period is custom).
  final DateTime? customEnd;

  const ReportsPeriodChanged(this.period, {this.customStart, this.customEnd});

  @override
  List<Object?> get props => [period, customStart, customEnd];
}

/// Applies a full filter set and reloads.
class ReportsFilterChanged extends ReportsEvent {
  final ExpenseHistoryFilter filter;

  const ReportsFilterChanged(this.filter);

  @override
  List<Object?> get props => [filter];
}
