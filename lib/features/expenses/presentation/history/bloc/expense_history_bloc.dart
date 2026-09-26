import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/domain/entities/budget_entity.dart';
import '../../../domain/entities/expense_category.dart';
import '../../../domain/entities/expense_entity.dart';
import '../../../domain/entities/expense_failure.dart';
import '../../../domain/usecases/calculate_expense_summary_usecase.dart';
import '../../../domain/usecases/filter_expenses_usecase.dart';
import '../../../domain/usecases/get_categories_usecase.dart';
import '../../../domain/usecases/get_expenses_for_budgets_usecase.dart';
import '../../../domain/usecases/get_expenses_usecase.dart';
import '../../../domain/usecases/page_expenses_usecase.dart';
import '../../../domain/usecases/search_expenses_usecase.dart';
import '../../../domain/usecases/sort_expenses_usecase.dart';
import '../../../../budget/domain/repository/budget_repository.dart';
import '../../../../../core/events/refresh_bus.dart';
import 'expense_history_event.dart';
import 'expense_history_state.dart';

/// Manages the expense history screen: loading, search (debounced), filtering,
/// sorting, grouping, pagination, summary calculations, and combined
/// multi-budget view mode.
class ExpenseHistoryBloc
    extends Bloc<ExpenseHistoryEvent, ExpenseHistoryState> {
  final GetExpensesUseCase getExpensesUseCase;
  final GetExpensesForBudgetsUseCase getExpensesForBudgetsUseCase;
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

  /// Ids already in `loadedExpenses`, so paging never duplicates a row.
  final Set<String> _loadedIds = <String>{};

  StreamSubscription<void>? _refreshSubscription;
  StreamSubscription<void>? _budgetSwitchSubscription;

  ExpenseHistoryBloc({
    required this.getExpensesUseCase,
    required this.getExpensesForBudgetsUseCase,
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
    on<ExpenseHistoryToggleViewMode>(_onToggleViewMode);
    on<ExpenseHistoryToggleBudgetSelection>(_onToggleBudgetSelection);
    on<ExpenseHistorySetBudgetSelection>(_onSetBudgetSelection);
    on<ExpenseHistorySelectAllBudgets>(_onSelectAllBudgets);
    on<ExpenseHistoryClearBudgetSelection>(_onClearBudgetSelection);
    on<ExpenseHistoryApplyCombinedView>(_onApplyCombinedView);
    on<ExpenseHistoryExitCombinedView>(_onExitCombinedView);
    on<ExpenseHistoryExpenseRemoved>(_onExpenseRemoved);

    // Auto-refresh when expenses change (created, updated, or deleted) so the
    // history, Dashboard, and Budget Engine stay in sync.
    _refreshSubscription = RefreshBuses.expenses.changes.listen((_) {
      if (!isClosed) {
        add(const ExpenseHistoryRefresh());
      }
    });

    // Reload when the active budget is switched so the history only shows
    // expenses belonging to the newly active budget.
    _budgetSwitchSubscription = RefreshBuses.budgets.changes.listen((_) {
      if (!isClosed) {
        add(const ExpenseHistoryRefresh());
      }
    });
  }

  /// Incremented by every load. Loads run concurrently (a bus refresh can
  /// arrive while a pull-to-refresh is in flight) and an older one finishing
  /// last would overwrite newer data and make the list flicker backwards, so
  /// a load only publishes its result if it is still the latest.
  int _loadToken = 0;

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    _refreshSubscription?.cancel();
    _budgetSwitchSubscription?.cancel();
    return super.close();
  }

  // ── Load / Refresh ──────────────────────────────────────────────────

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

  // ── Search / Filter / Sort ──────────────────────────────────────────

  Future<void> _onSearchChanged(
    ExpenseHistorySearchChanged event,
    Emitter<ExpenseHistoryState> emit,
  ) async {
    // The query is already in state: this is the debounced re-dispatch (or
    // a no-op edit), so apply it now. It must not arm another timer, or the
    // re-dispatch would re-arm itself every 300 ms for the life of the bloc
    // and keep resetting the list to its first page.
    if (state.query == event.query) {
      _searchTimer?.cancel();
      _recompute(emit, query: event.query);
      return;
    }

    // Publish the query immediately so the field and chips update, and
    // recompute the list once typing pauses.
    emit(state.copyWith(query: event.query));
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDebounce, () {
      if (!isClosed) {
        add(ExpenseHistorySearchChanged(event.query));
      }
    });
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
    // Kept as a field rather than rebuilt per page: recreating it from the
    // loaded list made a full scroll quadratic in the number of expenses.
    final newItems = page.items
        .where((expense) => _loadedIds.add(expense.id))
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

  // ── Combined mode events ────────────────────────────────────────────

  Future<void> _onToggleViewMode(
    ExpenseHistoryToggleViewMode event,
    Emitter<ExpenseHistoryState> emit,
  ) async {
    if (state.viewMode == ExpenseViewMode.combined) {
      // Switching back to single-budget mode
      emit(
        state.copyWith(
          viewMode: ExpenseViewMode.singleBudget,
          selectedBudgetIds: const [],
        ),
      );
      await _load(emit, showLoading: true);
    } else {
      // Entering combined mode — load budgets and keep previous selection
      if (state.allBudgets.isEmpty) {
        await _loadBudgets(emit);
      }
      emit(state.copyWith(viewMode: ExpenseViewMode.combined));
    }
  }

  Future<void> _onToggleBudgetSelection(
    ExpenseHistoryToggleBudgetSelection event,
    Emitter<ExpenseHistoryState> emit,
  ) async {
    final current = List<String>.from(state.selectedBudgetIds);
    if (current.contains(event.budgetId)) {
      current.remove(event.budgetId);
    } else {
      current.add(event.budgetId);
    }
    emit(state.copyWith(selectedBudgetIds: current));
  }

  Future<void> _onSetBudgetSelection(
    ExpenseHistorySetBudgetSelection event,
    Emitter<ExpenseHistoryState> emit,
  ) async {
    final known = state.allBudgets.map((b) => b.id).toSet();
    final next = event.budgetIds.where(known.contains).toList();
    emit(state.copyWith(selectedBudgetIds: next));
  }

  Future<void> _onSelectAllBudgets(
    ExpenseHistorySelectAllBudgets event,
    Emitter<ExpenseHistoryState> emit,
  ) async {
    emit(
      state.copyWith(
        selectedBudgetIds: state.allBudgets.map((b) => b.id).toList(),
      ),
    );
  }

  Future<void> _onClearBudgetSelection(
    ExpenseHistoryClearBudgetSelection event,
    Emitter<ExpenseHistoryState> emit,
  ) async {
    emit(state.copyWith(selectedBudgetIds: const []));
  }

  Future<void> _onApplyCombinedView(
    ExpenseHistoryApplyCombinedView event,
    Emitter<ExpenseHistoryState> emit,
  ) async {
    if (state.selectedBudgetIds.isEmpty) {
      emit(
        state.copyWith(
          status: ExpenseHistoryStatus.error,
          errorMessage: 'Select at least one budget to combine.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: ExpenseHistoryStatus.loading));

    final categoriesResult = await getCategoriesUseCase();
    List<ExpenseCategory> categories = const [];
    String? errorMessage;

    switch (categoriesResult) {
      case ExpenseSuccess(:final data):
        categories = data;
      case ExpenseError(:final failure):
        errorMessage = failure.message;
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

    final expensesResult = await getExpensesForBudgetsUseCase(
      budgetIds: state.selectedBudgetIds,
    );

    List<ExpenseEntity> expenses = const [];
    switch (expensesResult) {
      case ExpenseSuccess(:final data):
        expenses = data;
      case ExpenseError(:final failure):
        errorMessage = failure.message;
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
        viewMode: ExpenseViewMode.combined,
        allExpenses: expenses,
        categories: categories,
        clearBudgetScope: true,
      ),
    );

    _recompute(emit);
  }

  Future<void> _onExitCombinedView(
    ExpenseHistoryExitCombinedView event,
    Emitter<ExpenseHistoryState> emit,
  ) async {
    _searchTimer?.cancel();
    emit(
      state.copyWith(
        viewMode: ExpenseViewMode.singleBudget,
        selectedBudgetIds: const [],
        // The screen clears its search field on exit; keep state in step so
        // the reloaded list is not silently filtered by invisible text.
        query: '',
      ),
    );
    await _load(emit, showLoading: true);
  }

  Future<void> _onExpenseRemoved(
    ExpenseHistoryExpenseRemoved event,
    Emitter<ExpenseHistoryState> emit,
  ) async {
    final id = event.expenseId;
    if (!state.allExpenses.any((e) => e.id == id)) return;
    final all = state.allExpenses.where((e) => e.id != id).toList();
    _loadedIds.remove(id);
    _recompute(emit, allExpenses: all, keepLoaded: true);
  }

  // ── Private helpers ─────────────────────────────────────────────────

  /// Loads all available budgets from the repository and stores them in state.
  Future<void> _loadBudgets(Emitter<ExpenseHistoryState> emit) async {
    final budgets = await budgetRepository.getAllBudgets();
    final activeBudgets = budgets.where((b) => !b.isArchived).toList();
    final budgetMap = <String, BudgetEntity>{};
    for (final b in activeBudgets) {
      budgetMap[b.id] = b;
    }
    emit(state.copyWith(allBudgets: activeBudgets, budgetMap: budgetMap));
  }

  /// Loads expenses and categories from the repository, then recomputes the
  /// visible list, summary, and first page.
  ///
  /// When in combined mode with selected budgets, reloads expenses for
  /// those budgets instead of the single active budget — so that the
  /// user's selection survives pull-to-refresh and budget-switch events.
  Future<void> _load(
    Emitter<ExpenseHistoryState> emit, {
    required bool showLoading,
  }) async {
    final token = ++_loadToken;
    if (showLoading) {
      emit(state.copyWith(status: ExpenseHistoryStatus.refreshing));
    }

    final isCombined =
        state.viewMode == ExpenseViewMode.combined &&
        state.selectedBudgetIds.isNotEmpty;

    // Determine which data source to use.
    String? budgetId;
    String? budgetName;
    List<ExpenseEntity> expenses = const [];

    final categoriesResult = await getCategoriesUseCase();
    List<ExpenseCategory> categories = const [];
    String? errorMessage;

    switch (categoriesResult) {
      case ExpenseSuccess(:final data):
        categories = data;
      case ExpenseError(:final failure):
        errorMessage = failure.message;
    }

    if (isCombined) {
      // Combined mode — reload expenses for the selected budgets so the
      // selection and displayed list stay in sync after refresh.
      final expensesResult = await getExpensesForBudgetsUseCase(
        budgetIds: state.selectedBudgetIds,
      );
      switch (expensesResult) {
        case ExpenseSuccess(:final data):
          expenses = data;
        case ExpenseError(:final failure):
          errorMessage ??= failure.message;
      }
    } else {
      // Single-budget mode — scope to the active budget.
      final activeBudgetId = await budgetRepository.getActiveBudgetId();
      final activeBudget = activeBudgetId == null
          ? null
          : await budgetRepository.getBudgetById(activeBudgetId);
      budgetId = activeBudget?.id;
      budgetName = activeBudget?.name;

      final expensesResult = await getExpensesUseCase(budgetId: budgetId);
      switch (expensesResult) {
        case ExpenseSuccess(:final data):
          expenses = data;
        case ExpenseError(:final failure):
          errorMessage ??= failure.message;
      }
    }

    // A newer load has started since; let it publish instead.
    if (token != _loadToken) return;

    if (errorMessage != null) {
      emit(
        state.copyWith(
          status: ExpenseHistoryStatus.error,
          errorMessage: errorMessage,
        ),
      );
      return;
    }

    // One emission: the freshly loaded rows go straight through search,
    // filter and sort. Emitting the raw list first would briefly publish a
    // "loaded" state with nothing visible, which flashes the empty state.
    // A refresh keeps every page the user has already scrolled through, so
    // the list never shrinks back to its first page and jumps.
    _recompute(
      emit,
      allExpenses: expenses,
      categories: categories,
      budgetId: budgetId,
      budgetName: budgetName,
      clearBudgetScope: isCombined,
      keepLoaded: showLoading,
    );
  }

  /// Recomputes the visible list, summary, and first page based on the current
  /// query, filter, and sort. Preserves the user's search/filter/sort state.
  void _recompute(
    Emitter<ExpenseHistoryState> emit, {
    String? query,
    ExpenseHistoryFilter? filter,
    ExpenseSortOption? sort,
    List<ExpenseEntity>? allExpenses,
    List<ExpenseCategory>? categories,
    String? budgetId,
    String? budgetName,
    bool clearBudgetScope = false,
    bool keepLoaded = false,
  }) {
    final nextQuery = query ?? state.query;
    final nextFilter = filter ?? state.filter;
    final nextSort = sort ?? state.sort;
    final nextAll = allExpenses ?? state.allExpenses;
    final nextCategories = categories ?? state.categories;

    var visible = nextAll;
    visible = searchExpensesUseCase(
      expenses: visible,
      categories: nextCategories,
      query: nextQuery,
    );
    visible = filterExpensesUseCase(expenses: visible, filter: nextFilter);
    visible = sortExpensesUseCase(
      expenses: visible,
      categories: nextCategories,
      sort: nextSort,
    );

    final summary = calculateExpenseSummaryUseCase(visible);

    // Refreshes re-slice as many rows as were already on screen (at least
    // one page); filter, sort and search changes start again from the top.
    final target = keepLoaded
        ? math.max(state.loadedExpenses.length, pageExpensesUseCase.pageSize)
        : pageExpensesUseCase.pageSize;
    final end = math.min(target, visible.length);
    final page = ExpensePage(
      items: visible.sublist(0, end),
      offset: end,
      hasMore: end < visible.length,
    );
    _loadedIds
      ..clear()
      ..addAll(page.items.map((expense) => expense.id));

    emit(
      state.copyWith(
        status: ExpenseHistoryStatus.loaded,
        query: nextQuery,
        filter: nextFilter,
        sort: nextSort,
        allExpenses: nextAll,
        categories: nextCategories,
        budgetId: budgetId,
        budgetName: budgetName,
        clearBudgetScope: clearBudgetScope,
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
