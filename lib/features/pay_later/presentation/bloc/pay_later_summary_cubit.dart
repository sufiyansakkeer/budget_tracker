import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/events/refresh_bus.dart';
import '../../domain/entities/pay_later_failure.dart';
import '../../domain/entities/pay_later_overview.dart';
import '../../domain/usecases/get_pay_later_overview_usecase.dart';

/// What Home's Pay later row shows: the overview, or `null` while it is
/// loading or could not be read (Home then shows nothing, never an error).
///
/// Reloads whenever a tab, purchase or payment changes
/// ([RefreshBuses.payLater]), an expense changes ([RefreshBuses.expenses])
/// or the day turns ([RefreshBuses.day]). A reload that fails keeps what is
/// already shown.
class PayLaterSummaryCubit extends Cubit<PayLaterOverview?> {
  final GetPayLaterOverviewUseCase _getOverview;
  final List<StreamSubscription<void>> _subscriptions = [];

  /// Bumped by every load; an older, slower read never overwrites a newer
  /// one.
  int _generation = 0;

  PayLaterSummaryCubit({required GetPayLaterOverviewUseCase getOverview})
    : _getOverview = getOverview,
      super(null) {
    for (final bus in [
      RefreshBuses.payLater,
      RefreshBuses.expenses,
      RefreshBuses.day,
    ]) {
      _subscriptions.add(
        bus.changes.listen((_) {
          if (!isClosed) load();
        }),
      );
    }
  }

  Future<void> load() async {
    final generation = ++_generation;
    final result = await _getOverview();
    if (isClosed || generation != _generation) return;
    switch (result) {
      case PayLaterSuccess(:final data):
        emit(data);
      case PayLaterError(:final failure):
        debugPrint('[error] Loading the Pay later summary: ${failure.message}');
    }
  }

  @override
  Future<void> close() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    return super.close();
  }
}
