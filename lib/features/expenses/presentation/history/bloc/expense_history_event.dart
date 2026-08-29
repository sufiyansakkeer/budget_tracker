import 'package:equatable/equatable.dart';

import '../../../domain/entities/expense_history_filter.dart';
import '../../../domain/entities/expense_history_sort.dart';

export '../../../domain/entities/expense_history_filter.dart';
export '../../../domain/entities/expense_history_sort.dart';

/// Events for the ExpenseHistoryBloc.
abstract class ExpenseHistoryEvent extends Equatable {
  const ExpenseHistoryEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the initial history data (expenses + categories).
class ExpenseHistoryLoad extends ExpenseHistoryEvent {
  const ExpenseHistoryLoad();
}

/// Refreshes history, preserving filters where appropriate.
class ExpenseHistoryRefresh extends ExpenseHistoryEvent {
  const ExpenseHistoryRefresh();
}

/// Updates the search query (debounced in the bloc).
class ExpenseHistorySearchChanged extends ExpenseHistoryEvent {
  final String query;

  const ExpenseHistorySearchChanged(this.query);

  @override
  List<Object?> get props => [query];
}

/// Applies a full filter set.
class ExpenseHistoryFilterChanged extends ExpenseHistoryEvent {
  final ExpenseHistoryFilter filter;

  const ExpenseHistoryFilterChanged(this.filter);

  @override
  List<Object?> get props => [filter];
}

/// Applies a sort option.
class ExpenseHistorySortChanged extends ExpenseHistoryEvent {
  final ExpenseSortOption sort;

  const ExpenseHistorySortChanged(this.sort);

  @override
  List<Object?> get props => [sort];
}

/// Loads the next page of expenses.
class ExpenseHistoryLoadMore extends ExpenseHistoryEvent {
  const ExpenseHistoryLoadMore();
}

/// Clears all active filters and search query.
class ExpenseHistoryClearFilters extends ExpenseHistoryEvent {
  const ExpenseHistoryClearFilters();
}

// ── Combined mode events ────────────────────────────────────────────────

/// Toggles between single-budget and combined view modes.
class ExpenseHistoryToggleViewMode extends ExpenseHistoryEvent {
  const ExpenseHistoryToggleViewMode();
}

/// Toggles selection of a specific budget in the combined budget picker.
class ExpenseHistoryToggleBudgetSelection extends ExpenseHistoryEvent {
  final String budgetId;

  const ExpenseHistoryToggleBudgetSelection(this.budgetId);

  @override
  List<Object?> get props => [budgetId];
}

/// Selects all available budgets in the combined picker.
class ExpenseHistorySelectAllBudgets extends ExpenseHistoryEvent {
  const ExpenseHistorySelectAllBudgets();
}

/// Clears all budget selections in the combined picker.
class ExpenseHistoryClearBudgetSelection extends ExpenseHistoryEvent {
  const ExpenseHistoryClearBudgetSelection();
}

/// Applies the combined budget filter with the currently selected budgets.
/// At least one budget must be selected; emits an error message otherwise.
class ExpenseHistoryApplyCombinedView extends ExpenseHistoryEvent {
  const ExpenseHistoryApplyCombinedView();
}

/// Exits combined mode and returns to single-budget mode.
class ExpenseHistoryExitCombinedView extends ExpenseHistoryEvent {
  const ExpenseHistoryExitCombinedView();
}
