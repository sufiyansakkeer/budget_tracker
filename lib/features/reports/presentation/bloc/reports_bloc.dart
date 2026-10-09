import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/report_failure.dart';
import '../../domain/services/report_insight_generator.dart';
import '../../domain/usecases/get_report_data_usecase.dart';
import '../../../../core/events/refresh_bus.dart';
import 'reports_event.dart';
import 'reports_state.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../budget/domain/repository/budget_repository.dart';
import '../../domain/entities/report_period.dart';

/// Manages the reports screen: loading, refreshing, period changes, and
/// filters. All calculations happen in [GetReportDataUseCase] /
/// AnalyticsService — the bloc contains no calculation logic.
class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  final GetReportDataUseCase getReportDataUseCase;
  final ReportInsightGenerator insightGenerator;

  /// Reads the active budget for "This budget". Without it that period
  /// cannot be chosen.
  final BudgetRepository? budgetRepository;

  /// "Now" for the budget period's end; replaced in tests.
  final DateTime Function() clock;

  /// Said when "This Budget" is chosen with no active budget.
  static const String noBudgetMessage =
      'There is no active budget to report on.';

  StreamSubscription<void>? _refreshSubscription;
  StreamSubscription<void>? _budgetSwitchSubscription;

  ReportsBloc({
    required this.getReportDataUseCase,
    required this.insightGenerator,
    this.budgetRepository,
    this.clock = DateTime.now,
  }) : super(const ReportsState()) {
    on<ReportsLoad>(_onLoad);
    on<ReportsBudgetPeriodSelected>(_onBudgetPeriodSelected);
    on<ReportsRefresh>(_onRefresh);
    on<ReportsPeriodChanged>(_onPeriodChanged);
    on<ReportsFilterChanged>(_onFilterChanged);

    // Auto-refresh when expenses change so reports stay in sync.
    _refreshSubscription = RefreshBuses.expenses.changes.listen((_) {
      if (!isClosed) {
        add(const ReportsRefresh());
      }
    });

    // Reload when the active budget is switched so reports are scoped to the
    // newly active budget.
    _budgetSwitchSubscription = RefreshBuses.budgets.changes.listen((_) {
      if (!isClosed) {
        add(const ReportsRefresh());
      }
    });
  }

  @override
  Future<void> close() {
    _refreshSubscription?.cancel();
    _budgetSwitchSubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoad(ReportsLoad event, Emitter<ReportsState> emit) async {
    emit(
      state.copyWith(
        status: ReportsStatus.loading,
        period: event.period,
        filter: event.filter,
        clearError: true,
      ),
    );
    await _load(emit, showLoading: false);
  }

  Future<void> _onRefresh(
    ReportsRefresh event,
    Emitter<ReportsState> emit,
  ) async {
    await _load(emit, showLoading: true);
  }

  Future<void> _onPeriodChanged(
    ReportsPeriodChanged event,
    Emitter<ReportsState> emit,
  ) async {
    emit(
      state.copyWith(
        period: event.period,
        customStart: event.customStart,
        customEnd: event.customEnd,
        status: ReportsStatus.loading,
        clearError: true,
        followsBudget: false,
        clearBudget: true,
      ),
    );
    await _load(emit, showLoading: false);
  }

  Future<void> _onBudgetPeriodSelected(
    ReportsBudgetPeriodSelected event,
    Emitter<ReportsState> emit,
  ) async {
    emit(
      state.copyWith(
        followsBudget: true,
        status: ReportsStatus.loading,
        clearError: true,
      ),
    );
    await _load(emit, showLoading: false);
  }

  /// The active budget's period as a custom range: from its start to today,
  /// or to its end once it has ended. Days after today are left out, so the
  /// daily average is over days that have happened. Null when there is no
  /// active budget (or it cannot be read).
  Future<(BudgetEntity, DateTime, DateTime)?> _budgetRange() async {
    final repository = budgetRepository;
    if (repository == null) return null;
    final BudgetEntity? budget;
    try {
      budget = await repository.getActiveBudget();
    } catch (_) {
      return null;
    }
    if (budget == null) return null;
    final now = clock();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(
      budget.startDate.year,
      budget.startDate.month,
      budget.startDate.day,
    );
    final end = DateTime(
      budget.endDate.year,
      budget.endDate.month,
      budget.endDate.day,
    );
    final last = end.isBefore(today) ? end : today;
    return (budget, start, last.isBefore(start) ? start : last);
  }

  Future<void> _onFilterChanged(
    ReportsFilterChanged event,
    Emitter<ReportsState> emit,
  ) async {
    emit(
      state.copyWith(
        filter: event.filter,
        status: ReportsStatus.loading,
        clearError: true,
      ),
    );
    await _load(emit, showLoading: false);
  }

  Future<void> _load(
    Emitter<ReportsState> emit, {
    required bool showLoading,
  }) async {
    if (showLoading) {
      emit(state.copyWith(status: ReportsStatus.refreshing, clearError: true));
    }

    // "This budget" follows the active budget: its range is read again on
    // every load, so a budget switch or an edit to its dates moves it.
    if (state.followsBudget) {
      final resolved = await _budgetRange();
      if (resolved == null) {
        emit(
          state.copyWith(
            status: ReportsStatus.error,
            errorMessage: noBudgetMessage,
            followsBudget: false,
            clearBudget: true,
          ),
        );
        return;
      }
      final (budget, start, end) = resolved;
      emit(
        state.copyWith(
          period: ReportPeriod.custom,
          customStart: start,
          customEnd: end,
          budget: budget,
        ),
      );
    }

    final result = await getReportDataUseCase(
      period: state.period,
      filter: state.filter,
      customStart: state.customStart,
      customEnd: state.customEnd,
    );

    switch (result) {
      case ReportError(:final failure):
        emit(
          state.copyWith(
            status: ReportsStatus.error,
            errorMessage: failure.message,
            data: null,
            insights: null,
            isEmpty: false,
          ),
        );
      case ReportSuccess(:final data):
        final insights = insightGenerator.generate(data);
        emit(
          state.copyWith(
            status: ReportsStatus.loaded,
            data: data,
            insights: insights,
            isEmpty: data.isEmpty,
            clearError: true,
          ),
        );
    }
  }
}
