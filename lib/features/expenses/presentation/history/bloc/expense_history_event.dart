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
