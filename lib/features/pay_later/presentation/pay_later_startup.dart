import 'dart:developer' as developer;

import '../../../core/events/refresh_bus.dart';
import '../domain/usecases/reconcile_tab_usecase.dart';

/// Reconciles every Pay later tab once at app start, then notifies [bus]
/// (by default [RefreshBuses.payLater]) so a screen already open shows the
/// reconciled figures. A failure is logged and left for the next start:
/// each tab is reconciled again whenever it is written.
Future<void> reconcilePayLaterTabsOnStartup(
  ReconcileTabUseCase reconcile, {
  RefreshBus? bus,
}) async {
  try {
    await reconcile.all();
  } catch (e, stackTrace) {
    developer.log(
      'Reconciling Pay later tabs on startup failed: $e',
      name: 'PayLater',
      error: e,
      stackTrace: stackTrace,
    );
    return;
  }
  (bus ?? RefreshBuses.payLater).notifyChanged();
}
