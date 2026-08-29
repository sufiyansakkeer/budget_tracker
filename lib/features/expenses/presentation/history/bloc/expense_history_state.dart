import 'package:equatable/equatable.dart';

import '../../../../../core/domain/entities/budget_entity.dart';
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

/// View mode for the expense history screen.
enum ExpenseViewMode { singleBudget, combined }

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

  /// The active budget id the history is scoped to (null = no active budget).
  final String? budgetId;

  /// Display name of the active budget the history is scoped to.
  final String? budgetName;

  final String? errorMessage;

  // ── Combined mode fields ─────────────────────────────────────────────

  /// Current view mode (single budget or combined).
  final ExpenseViewMode viewMode;

  /// Budget IDs selected for the combined view.
  final List<String> selectedBudgetIds;

  /// All available (non-archived) budgets.
  final List<BudgetEntity> allBudgets;

  /// Map of budget ID to BudgetEntity for efficient lookup.
  final Map<String, BudgetEntity> budgetMap;

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
    this.budgetId,
    this.budgetName,
    this.errorMessage,
    this.viewMode = ExpenseViewMode.singleBudget,
    this.selectedBudgetIds = const [],
    this.allBudgets = const [],
    this.budgetMap = const {},
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
    String? budgetId,
    String? budgetName,
    String? errorMessage,
    bool clearError = false,
    ExpenseViewMode? viewMode,
    List<String>? selectedBudgetIds,
    List<BudgetEntity>? allBudgets,
    Map<String, BudgetEntity>? budgetMap,
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
      budgetId: budgetId ?? this.budgetId,
      budgetName: budgetName ?? this.budgetName,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      viewMode: viewMode ?? this.viewMode,
      selectedBudgetIds: selectedBudgetIds ?? this.selectedBudgetIds,
      allBudgets: allBudgets ?? this.allBudgets,
      budgetMap: budgetMap ?? this.budgetMap,
    );
  }

  bool get isCombinedMode => viewMode == ExpenseViewMode.combined;

  /// Total amount spent across all visible expenses.
  double get combinedTotalAmount =>
      visibleExpenses.fold(0.0, (sum, e) => sum + e.amount);

  /// Compact label for selected budgets (e.g. "Food \u2022 Travel \u2022 Shopping +2").
  String get selectedBudgetsLabel {
    if (selectedBudgetIds.isEmpty) return '';
    final names = selectedBudgetIds
        .map((id) => budgetMap[id]?.name ?? id)
        .toList();
    if (names.length <= 3) return names.join(' \u2022 ');
    return '${names.sublist(0, 3).join(' \u2022 ')} +${names.length - 3}';
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
    budgetId,
    budgetName,
    errorMessage,
    viewMode,
    selectedBudgetIds,
    allBudgets,
  ];
}
