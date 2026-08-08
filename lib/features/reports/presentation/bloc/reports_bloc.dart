import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../budget/presentation/bloc/budget_bloc.dart';
import '../../../expenses/presentation/bloc/expense_refresh_bus.dart';
import '../../domain/entities/report_failure.dart';
import '../../domain/services/report_insight_generator.dart';
import '../../domain/usecases/get_report_data_usecase.dart';
import 'reports_event.dart';
import 'reports_state.dart';

/// Manages the reports screen: loading, refreshing, period changes, and
/// filters. All calculations happen in [GetReportDataUseCase] /
/// AnalyticsService — the bloc contains no calculation logic.
class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  final GetReportDataUseCase getReportDataUseCase;
  final ReportInsightGenerator insightGenerator;

  StreamSubscription<void>? _refreshSubscription;
  StreamSubscription<void>? _budgetSwitchSubscription;

  ReportsBloc({
    required this.getReportDataUseCase,
    required this.insightGenerator,
  }) : super(const ReportsState()) {
    on<ReportsLoad>(_onLoad);
    on<ReportsRefresh>(_onRefresh);
    on<ReportsPeriodChanged>(_onPeriodChanged);
    on<ReportsFilterChanged>(_onFilterChanged);

    // Auto-refresh when expenses change so reports stay in sync.
    _refreshSubscription = ExpenseRefreshBus.instance.changes.listen((_) {
      if (!isClosed) {
        add(const ReportsRefresh());
      }
    });

    // Reload when the active budget is switched so reports are scoped to the
    // newly active budget.
    _budgetSwitchSubscription = BudgetRefreshBus.instance.changes.listen((_) {
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
      ),
    );
    await _load(emit, showLoading: false);
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
