import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/events/refresh_bus.dart';
import '../../domain/entities/pay_later_failure.dart';
import '../../domain/usecases/get_pay_later_analytics_usecase.dart';
import '../../domain/usecases/get_pay_later_overview_usecase.dart';
import '../pay_later_failure_copy.dart';
import 'pay_later_overview_event.dart';
import 'pay_later_overview_state.dart';

/// The Pay later overview: totals, tabs, recent activity and charts.
///
/// Reloads whenever a tab, purchase or payment changes
/// ([RefreshBuses.payLater]), an expense changes ([RefreshBuses.expenses],
/// since a purchase is an expense) or the day turns ([RefreshBuses.day]:
/// overdue, settle-up days and "this month" move with it).
class PayLaterOverviewBloc
    extends Bloc<PayLaterOverviewEvent, PayLaterOverviewState> {
  /// Shown when the first load fails for a reason not written for people.
  static const loadFailedMessage =
      'Your tabs are still on this device. Try again in a moment.';

  final GetPayLaterOverviewUseCase getOverview;
  final GetPayLaterAnalyticsUseCase getAnalytics;

  final List<StreamSubscription<void>> _subscriptions = [];

  /// Bumped by every load; a load that finds it moved on drops its result,
  /// so an older, slower read never overwrites a newer one.
  int _loadGeneration = 0;

  /// The same for the charts, which a currency switch reloads on their own.
  int _chartsGeneration = 0;

  PayLaterOverviewBloc({required this.getOverview, required this.getAnalytics})
    : super(const PayLaterOverviewState()) {
    on<PayLaterOverviewStarted>(
      (event, emit) => _load(emit, showLoading: true),
    );
    on<PayLaterOverviewRefreshed>(
      (event, emit) => _load(emit, showLoading: false),
    );
    on<PayLaterOverviewCurrencySelected>(_onCurrencySelected);

    for (final bus in [
      RefreshBuses.payLater,
      RefreshBuses.expenses,
      RefreshBuses.day,
    ]) {
      _subscriptions.add(
        bus.changes.listen((_) {
          if (!isClosed) add(const PayLaterOverviewRefreshed());
        }),
      );
    }
  }

  @override
  Future<void> close() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    return super.close();
  }

  Future<void> _load(
    Emitter<PayLaterOverviewState> emit, {
    required bool showLoading,
  }) async {
    final generation = ++_loadGeneration;
    if (showLoading) {
      emit(
        state.copyWith(
          status: PayLaterOverviewStatus.loading,
          clearErrorMessage: true,
        ),
      );
    }
    final result = await getOverview();
    if (generation != _loadGeneration) return;
    switch (result) {
      case PayLaterError(:final failure):
        debugPrint('[error] Loading Pay later: ${failure.message}');
        // A refresh that fails keeps what is on screen; only a screen with
        // nothing to show turns into the error.
        if (showLoading || state.overview == null) {
          emit(
            state.copyWith(
              status: PayLaterOverviewStatus.error,
              errorMessage: failure.shown(loadFailedMessage),
            ),
          );
        }
      case PayLaterSuccess(:final data):
        final currencies = [for (final t in data.totals) t.currency];
        final currency = currencies.contains(state.currency)
            ? state.currency
            : currencies.firstOrNull;
        if (currency == null) {
          _chartsGeneration++;
          emit(
            state.copyWith(
              status: PayLaterOverviewStatus.loaded,
              overview: data,
              clearCurrency: true,
              analyticsStatus: PayLaterAnalyticsStatus.none,
              clearAnalytics: true,
              clearErrorMessage: true,
            ),
          );
          return;
        }
        // The same currency keeps its charts on screen while they reload.
        final keepCharts =
            currency == state.currency && state.analytics != null;
        emit(
          state.copyWith(
            status: PayLaterOverviewStatus.loaded,
            overview: data,
            currency: currency,
            analyticsStatus: keepCharts
                ? state.analyticsStatus
                : PayLaterAnalyticsStatus.loading,
            clearAnalytics: !keepCharts,
            clearErrorMessage: true,
          ),
        );
        await _loadCharts(emit, currency);
    }
  }

  Future<void> _onCurrencySelected(
    PayLaterOverviewCurrencySelected event,
    Emitter<PayLaterOverviewState> emit,
  ) async {
    if (event.currency == state.currency) return;
    emit(
      state.copyWith(
        currency: event.currency,
        analyticsStatus: PayLaterAnalyticsStatus.loading,
        clearAnalytics: true,
      ),
    );
    await _loadCharts(emit, event.currency);
  }

  Future<void> _loadCharts(
    Emitter<PayLaterOverviewState> emit,
    String currency,
  ) async {
    final generation = ++_chartsGeneration;
    final result = await getAnalytics(currency: currency);
    if (generation != _chartsGeneration) return;
    switch (result) {
      case PayLaterSuccess(:final data):
        emit(
          state.copyWith(
            analyticsStatus: PayLaterAnalyticsStatus.loaded,
            analytics: data,
          ),
        );
      case PayLaterError(:final failure):
        debugPrint('[error] Loading Pay later charts: ${failure.message}');
        emit(
          state.copyWith(
            analyticsStatus: PayLaterAnalyticsStatus.error,
            clearAnalytics: true,
          ),
        );
    }
  }
}
