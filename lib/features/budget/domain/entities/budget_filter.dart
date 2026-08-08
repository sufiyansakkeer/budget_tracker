import 'package:equatable/equatable.dart';

/// Defines how budgets should be filtered when queried.
enum BudgetFilter {
  /// All budgets regardless of archive state.
  all,

  /// Only non-archived budgets.
  active,

  /// Only archived budgets.
  archived,
}

/// Options for querying budgets with filtering and search.
class BudgetQueryOptions extends Equatable {
  final BudgetFilter filter;
  final String? searchQuery;

  const BudgetQueryOptions({this.filter = BudgetFilter.all, this.searchQuery});

  @override
  List<Object?> get props => [filter, searchQuery];
}
