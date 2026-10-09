import 'dart:async';
import 'dart:developer' as developer;

import '../../core/events/refresh_bus.dart';
import 'home_widget_service.dart';

/// Subscribes to in-app data-change buses and triggers home-screen widget
/// updates whenever relevant data is modified.
///
/// This keeps widget-refresh logic decoupled from individual BLoCs while
/// ensuring the widget stays current after:
/// - Expense created / updated / deleted
/// - Budget created / updated / deleted / switched
/// - Bill created / updated / deleted / paid / unpaid / linked (bills set
///   aside from a budget change its Today's Safe Spending)
/// - Colour palette changed (the widget is drawn in the app's palette)
class WidgetRefreshListener {
  final HomeWidgetService _widgetService;

  /// Emits when the widget's look changes (the palette), if given.
  final Stream<Object?>? _appearanceChanges;

  StreamSubscription<void>? _expenseSubscription;
  StreamSubscription<void>? _budgetSubscription;
  StreamSubscription<void>? _billSubscription;
  StreamSubscription<Object?>? _appearanceSubscription;

  WidgetRefreshListener({
    required HomeWidgetService widgetService,
    Stream<Object?>? appearanceChanges,
  }) : _widgetService = widgetService,
       _appearanceChanges = appearanceChanges;

  /// Starts listening to the expense, budget and bill change buses, and to
  /// appearance changes.
  void startListening() {
    _expenseSubscription?.cancel();
    _budgetSubscription?.cancel();
    _billSubscription?.cancel();
    _appearanceSubscription?.cancel();

    _expenseSubscription = RefreshBuses.expenses.changes.listen((_) {
      _updateWidget('expense change');
    });

    _budgetSubscription = RefreshBuses.budgets.changes.listen((_) {
      _updateWidget('budget change');
    });

    _billSubscription = RefreshBuses.bills.changes.listen((_) {
      _updateWidget('bill change');
    });

    _appearanceSubscription = _appearanceChanges?.listen((_) {
      _updateWidget('appearance change');
    });
  }

  /// Stops listening and releases resources.
  void stopListening() {
    _expenseSubscription?.cancel();
    _budgetSubscription?.cancel();
    _billSubscription?.cancel();
    _appearanceSubscription?.cancel();
    _expenseSubscription = null;
    _budgetSubscription = null;
    _billSubscription = null;
    _appearanceSubscription = null;
  }

  Future<void> _updateWidget(String reason) async {
    try {
      developer.log(
        '[WidgetRefreshListener] Triggering widget update: $reason',
        name: 'WidgetRefreshListener',
      );
      await _widgetService.updateWidgetData();
    } catch (e) {
      developer.log(
        '[WidgetRefreshListener] Widget update failed: $e',
        name: 'WidgetRefreshListener',
      );
    }
  }
}
