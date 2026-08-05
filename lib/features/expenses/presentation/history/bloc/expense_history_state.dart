import 'package:equatable/equatable.dart';

import '../../../domain/entities/expense_category.dart';
import '../../../domain/entities/expense_entity.dart';
import '../../../domain/entities/expense_history_filter.dart';
import '../../../domain/entities/expense_history_sort.dart';
import '../../../domain/entities/expense_history_summary.dart';

export '../../../domain/entities/expense_history_filter.dart';
export '../../../domain/entities/expense_history_sort.dart';

enum ExpenseHistoryStatus {
  initial,
  loading,
  loaded,
  loadingMore,
  refreshing,
  error,
}

/// Immutable state for the ExpenseHistoryBloc.
class ExpenseHistoryState extends Equatable {
  final ExpenseHistoryStatus status;

  /// All expenses loaded from the repository (the full unfiltered set).
  final List<ExpenseEntity> allExpenses;

  /// Categories used to resolve category names/colors.
  final List<ExpenseCategory> categories;

  /// Active search query.
  final String query;

  /// Active filter.
  final ExpenseHistoryFilter filter;

  /// Active sort option.
  final ExpenseSortOption sort;

  /// The expenses currently visible (after search + filter + sort).
  final List<ExpenseEntity> visibleExpenses;

  /// The expenses returned for the current loaded page (pre-slicing).
  final List<ExpenseEntity> pageExpenses;

  /// Complete list of loaded expenses shown in the list (accumulated).
  final List<ExpenseEntity> loadedExpenses;

  /// Summary for the currently visible results.
  final ExpenseHistorySummary summary;

  /// Number of items already loaded (pagination offset).
  final int loadedCount;

  /// Whether more pages are available.
  final bool hasMore;

  final String? errorMessage;

  const ExpenseHistoryState({
    this.status = ExpenseHistoryStatus.initial,
    this.allExpenses = const [],
    this.categories = const [],
    this.query = '',
    this.filter = const ExpenseHistoryFilter(),
    this.sort = ExpenseSortOption.newestFirst,
    this.visibleExpenses = const [],
    this.pageExpenses = const [],
    this.loadedExpenses = const [],
    this.summary = ExpenseHistorySummary.empty,
    this.loadedCount = 0,
    this.hasMore = false,
    this.errorMessage,
  });

  bool get isEmpty =>
      status == ExpenseHistoryStatus.loaded && visibleExpenses.isEmpty;

  ExpenseHistoryState copyWith({
    ExpenseHistoryStatus? status,
    List<ExpenseEntity>? allExpenses,
    List<ExpenseCategory>? categories,
    String? query,
    ExpenseHistoryFilter? filter,
    ExpenseSortOption? sort,
    List<ExpenseEntity>? visibleExpenses,
    List<ExpenseEntity>? pageExpenses,
    List<ExpenseEntity>? loadedExpenses,
    ExpenseHistorySummary? summary,
    int? loadedCount,
    bool? hasMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ExpenseHistoryState(
      status: status ?? this.status,
      allExpenses: allExpenses ?? this.allExpenses,
      categories: categories ?? this.categories,
      query: query ?? this.query,
      filter: filter ?? this.filter,
      sort: sort ?? this.sort,
      visibleExpenses: visibleExpenses ?? this.visibleExpenses,
      pageExpenses: pageExpenses ?? this.pageExpenses,
      loadedExpenses: loadedExpenses ?? this.loadedExpenses,
      summary: summary ?? this.summary,
      loadedCount: loadedCount ?? this.loadedCount,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    allExpenses,
    categories,
    query,
    filter,
    sort,
    visibleExpenses,
    pageExpenses,
    loadedExpenses,
    summary,
    loadedCount,
    hasMore,
    errorMessage,
  ];
}
