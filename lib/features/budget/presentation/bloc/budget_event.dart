import 'package:equatable/equatable.dart';

abstract class BudgetEvent extends Equatable {
  const BudgetEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the budget summary on initial screen open.
class BudgetLoadSummaryEvent extends BudgetEvent {
  const BudgetLoadSummaryEvent();
}

/// Refreshes all budget calculations (e.g. pull-to-refresh).
class BudgetRefreshEvent extends BudgetEvent {
  const BudgetRefreshEvent();
}

/// Recalculates after an expense or budget change.
class BudgetRecalculateEvent extends BudgetEvent {
  const BudgetRecalculateEvent();
}

/// Switches the active budget to [budgetId] and recalculates.
class BudgetSwitchEvent extends BudgetEvent {
  final String budgetId;

  const BudgetSwitchEvent(this.budgetId);

  @override
  List<Object?> get props => [budgetId];
}
