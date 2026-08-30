import 'dart:async';
import 'dart:developer' as developer;

import '../expenses/presentation/bloc/expense_refresh_bus.dart';
import '../budget/presentation/bloc/budget_bloc.dart';
import 'home_widget_service.dart';

/// Subscribes to in-app data-change buses and triggers home-screen widget
/// updates whenever relevant data is modified.
///
/// This keeps widget-refresh logic decoupled from individual BLoCs while
/// ensuring the widget stays current after:
/// - Expense created / updated / deleted
/// - Budget created / updated / deleted / switched
class WidgetRefreshListener {
  final HomeWidgetService _widgetService;

  StreamSubscription<void>? _expenseSubscription;
  StreamSubscription<void>? _budgetSubscription;

  WidgetRefreshListener({required HomeWidgetService widgetService})
    : _widgetService = widgetService;

  /// Starts listening to both expense and budget change buses.
  void startListening() {
    _expenseSubscription?.cancel();
    _budgetSubscription?.cancel();

    _expenseSubscription = ExpenseRefreshBus.instance.changes.listen((_) {
      _updateWidget('expense change');
    });

    _budgetSubscription = BudgetRefreshBus.instance.changes.listen((_) {
      _updateWidget('budget change');
    });
  }

  /// Stops listening and releases resources.
  void stopListening() {
    _expenseSubscription?.cancel();
    _budgetSubscription?.cancel();
    _expenseSubscription = null;
    _budgetSubscription = null;
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
