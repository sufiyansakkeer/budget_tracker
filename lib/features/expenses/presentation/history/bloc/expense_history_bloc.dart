import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/expense_category.dart';
import '../../../domain/entities/expense_entity.dart';
import '../../../domain/entities/expense_failure.dart';
import '../../../domain/usecases/calculate_expense_summary_usecase.dart';
import '../../../domain/usecases/filter_expenses_usecase.dart';
import '../../../domain/usecases/get_categories_usecase.dart';
import '../../../domain/usecases/get_expenses_usecase.dart';
import '../../../domain/usecases/page_expenses_usecase.dart';
import '../../../domain/usecases/search_expenses_usecase.dart';
import '../../../domain/usecases/sort_expenses_usecase.dart';
import '../../../../budget/domain/repository/budget_repository.dart';
import '../../../../budget/presentation/bloc/budget_bloc.dart';
import '../../bloc/expense_refresh_bus.dart';
import 'expense_history_event.dart';
import 'expense_history_state.dart';

/// Manages the expense history screen: loading, search (debounced), filtering,
/// sorting, grouping, pagination, and summary calculations.
///
/// Reuses the existing [GetExpensesUseCase] and [GetCategoriesUseCase] — no
/// CRUD logic is duplicated here.
class ExpenseHistoryBloc
    extends Bloc<ExpenseHistoryEvent, ExpenseHistoryState> {
  final GetExpensesUseCase getExpensesUseCase;
  final GetCategoriesUseCase getCategoriesUseCase;
  final SearchExpensesUseCase searchExpensesUseCase;
  final FilterExpensesUseCase filterExpensesUseCase;
  final SortExpensesUseCase sortExpensesUseCase;
  final CalculateExpenseSummaryUseCase calculateExpenseSummaryUseCase;
  final PageExpensesUseCase pageExpensesUseCase;
  final BudgetRepository budgetRepository;

  /// Debounce window for search input.
  static const Duration searchDebounce = Duration(milliseconds: 300);

  Timer? _searchTimer;
  StreamSubscription<void>? _refreshSubscription;
  StreamSubscription<void>? _budgetSwitchSubscription;

  ExpenseHistoryBloc({
    required this.getExpensesUseCase,
    required this.getCategoriesUseCase,
    required this.searchExpensesUseCase,
    required this.filterExpensesUseCase,
    required this.sortExpensesUseCase,
    required this.calculateExpenseSummaryUseCase,
    required this.pageExpensesUseCase,
    required this.budgetRepository,
  }) : super(const ExpenseHistoryState()) {
    on<ExpenseHistoryLoad>(_onLoad);
    on<ExpenseHistoryRefresh>(_onRefresh);
    on<ExpenseHistorySearchChanged>(_onSearchChanged);
    on<ExpenseHistoryFilterChanged>(_onFilterChanged);
    on<ExpenseHistorySortChanged>(_onSortChanged);
    on<ExpenseHistoryLoadMore>(_onLoadMore);
    on<ExpenseHistoryClearFilters>(_onClearFilters);

    // Auto-refresh when expenses change (created, updated, or deleted) so the
    // history, Dashboard, and Budget Engine stay in sync.
    _refreshSubscription = ExpenseRefreshBus.instance.changes.listen((_) {
      if (!isClosed) {
        add(const ExpenseHistoryRefresh());
      }
    });

    // Reload when the active budget is switched so the history only shows
    // expenses belonging to the newly active budget.
    _budgetSwitchSubscription = BudgetRefreshBus.instance.changes.listen((_) {
      if (!isClosed) {
        add(const ExpenseHistoryRefresh());
      }
    });
  }

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    _refreshSubscription?.cancel();
    _budgetSwitchSubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoad(
    ExpenseHistoryLoad event,
    Emitter<ExpenseHistoryState> emit,
  ) async {
    emit(state.copyWith(status: ExpenseHistoryStatus.loading));
    await _load(emit, showLoading: false);
  }

  Future<void> _onRefresh(
    ExpenseHistoryRefresh event,
    Emitter<ExpenseHistoryState> emit,
  ) async {
    await _load(emit, showLoading: true);
  }

  Future<void> _onSearchChanged(
    ExpenseHistorySearchChanged event,
    Emitter<ExpenseHistoryState> emit,
  ) async {
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDebounce, () {
      if (!isClosed) {
        add(ExpenseHistorySearchChanged(event.query));
      }
    });

    // Emit query immediately so the UI clears/updates the search field, but
    // only recompute once the debounce fires.
    if (state.query == event.query) {
      _recompute(emit, query: event.query);
    } else {
      emit(state.copyWith(query: event.query));
    }
  }

  Future<void> _onFilterChanged(
    ExpenseHistoryFilterChanged event,
    Emitter<ExpenseHistoryState> emit,
  ) async {
    _recompute(emit, filter: event.filter);
  }

  Future<void> _onSortChanged(
    ExpenseHistorySortChanged event,
    Emitter<ExpenseHistoryState> emit,
  ) async {
    _recompute(emit, sort: event.sort);
  }

  Future<void> _onLoadMore(
    ExpenseHistoryLoadMore event,
    Emitter<ExpenseHistoryState> emit,
  ) async {
    if (state.status == ExpenseHistoryStatus.loadingMore ||
        state.status == ExpenseHistoryStatus.loading ||
        !state.hasMore) {
      return;
    }

    emit(state.copyWith(status: ExpenseHistoryStatus.loadingMore));
    final page = pageExpensesUseCase(
      offset: state.loadedCount,
      items: state.visibleExpenses,
    );
    final loadedIds = state.loadedExpenses.map((expense) => expense.id).toSet();
    final newItems = page.items
        .where((expense) => loadedIds.add(expense.id))
        .toList();

    emit(
      state.copyWith(
        status: ExpenseHistoryStatus.loaded,
        loadedExpenses: [...state.loadedExpenses, ...newItems],
        loadedCount: page.offset,
        hasMore: page.hasMore,
      ),
    );
  }

  Future<void> _onClearFilters(
    ExpenseHistoryClearFilters event,
    Emitter<ExpenseHistoryState> emit,
  ) async {
    _recompute(emit, query: '', filter: const ExpenseHistoryFilter());
  }

  /// Loads expenses and categories from the repository, then recomputes the
  /// visible list, summary, and first page.
  Future<void> _load(
    Emitter<ExpenseHistoryState> emit, {
    required bool showLoading,
  }) async {
    if (showLoading) {
      emit(state.copyWith(status: ExpenseHistoryStatus.refreshing));
    }

    // Resolve the active budget so history is scoped to that budget only.
    final activeBudgetId = await budgetRepository.getActiveBudgetId();
    final activeBudget = activeBudgetId == null
        ? null
        : await budgetRepository.getBudgetById(activeBudgetId);
    final budgetId = activeBudget?.id;
    final budgetName = activeBudget?.name;

    final expensesResult = await getExpensesUseCase(budgetId: budgetId);
    final categoriesResult = await getCategoriesUseCase();

    List<ExpenseEntity> expenses = const [];
    List<ExpenseCategory> categories = const [];
    String? errorMessage;

    switch (expensesResult) {
      case ExpenseSuccess(:final data):
        expenses = data;
      case ExpenseError(:final failure):
        errorMessage = failure.message;
    }

    switch (categoriesResult) {
      case ExpenseSuccess(:final data):
        categories = data;
      case ExpenseError(:final failure):
        errorMessage ??= failure.message;
    }

    if (errorMessage != null) {
      emit(
        state.copyWith(
          status: ExpenseHistoryStatus.error,
          errorMessage: errorMessage,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: ExpenseHistoryStatus.loaded,
        allExpenses: expenses,
        categories: categories,
        budgetId: budgetId,
        budgetName: budgetName,
      ),
    );

    _recompute(emit);
  }

  /// Recomputes the visible list, summary, and first page based on the current
  /// query, filter, and sort. Preserves the user's search/filter/sort state.
  void _recompute(
    Emitter<ExpenseHistoryState> emit, {
    String? query,
    ExpenseHistoryFilter? filter,
    ExpenseSortOption? sort,
  }) {
    final nextQuery = query ?? state.query;
    final nextFilter = filter ?? state.filter;
    final nextSort = sort ?? state.sort;

    var visible = state.allExpenses;
    visible = searchExpensesUseCase(
      expenses: visible,
      categories: state.categories,
      query: nextQuery,
    );
    visible = filterExpensesUseCase(expenses: visible, filter: nextFilter);
    visible = sortExpensesUseCase(
      expenses: visible,
      categories: state.categories,
      sort: nextSort,
    );

    final summary = calculateExpenseSummaryUseCase(visible);

    final page = pageExpensesUseCase(offset: 0, items: visible);

    emit(
      state.copyWith(
        status: ExpenseHistoryStatus.loaded,
        query: nextQuery,
        filter: nextFilter,
        sort: nextSort,
        visibleExpenses: visible,
        pageExpenses: page.items,
        loadedExpenses: page.items,
        loadedCount: page.offset,
        hasMore: page.hasMore,
        summary: summary,
        clearError: true,
      ),
    );
  }
}
