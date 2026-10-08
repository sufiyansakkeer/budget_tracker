import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constants/app_motion.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/theme/app_colors_extension.dart';
import '../../../../../core/widgets/app_state_switcher.dart';
import '../../../../../core/widgets/delayed_reveal.dart';
import '../../../../../core/widgets/info_content.dart';
import '../../../../../core/widgets/info_icon.dart';
import '../../../../../core/widgets/loading_skeleton.dart';
import '../../../domain/entities/expense_category.dart';
import '../../../domain/entities/expense_entity.dart';
import '../../../domain/entities/expense_group.dart';
import '../../../domain/usecases/group_expenses_usecase.dart';
import '../../bloc/expense_bloc.dart';
import '../../bloc/expense_event.dart';
import '../../bloc/expense_state.dart';
import '../bloc/expense_history_bloc.dart';
import '../bloc/expense_history_event.dart';
import '../bloc/expense_history_state.dart';
import '../widgets/active_filter_chips.dart';
import '../widgets/budget_info_bottom_sheet.dart';
import '../widgets/budget_selection_sheet.dart';
import '../widgets/expense_group_header.dart';
import '../widgets/expense_history_empty_state.dart';
import '../widgets/expense_history_error_widget.dart';
import '../widgets/expense_history_item.dart';
import '../widgets/expense_search_bar.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/loading_more_indicator.dart';
import '../widgets/quick_filter_chips.dart';
import '../widgets/sort_bottom_sheet.dart';
import '../../widgets/expense_actions_sheet.dart';
import '../../widgets/move_expense_sheet.dart';
import '../widgets/summary_card.dart';
import '../../quick_add/quick_add_sheet.dart';
import '../../../../budget/presentation/widgets/active_budget_selector.dart';
import '../../../../../core/domain/entities/budget_entity.dart';
import '../../../../../core/widgets/app_fab.dart';
import '../../../../../core/widgets/fade_slide_in.dart';
import '../../../../../core/navigation/push_unique.dart';
import '../../../../../core/widgets/app_animated_size.dart';

/// Expense history: search, filters, sorting, day grouping, pagination,
/// swipe-to-delete, pull-to-refresh, and the combined multi-budget view.
///
/// One scroll view: the title, the budget menu (where the combined view
/// lives), search and chips scroll away with the list, so the expenses get
/// the screen. The summary is a line of type, not a card.
class ExpenseHistoryScreen extends StatefulWidget {
  const ExpenseHistoryScreen({super.key});

  @override
  State<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final GroupExpensesUseCase _groupExpensesUseCase =
      const GroupExpensesUseCase();
  final ScrollController _scrollController = ScrollController();

  /// The add button shrinks to an icon while scrolling down so it never
  /// covers the amounts, and grows back when scrolling up.
  bool _fabExtended = true;

  bool _onUserScroll(UserScrollNotification notification) {
    final extended = switch (notification.direction) {
      ScrollDirection.reverse => false,
      ScrollDirection.forward => true,
      ScrollDirection.idle => _fabExtended,
    };
    if (extended != _fabExtended) setState(() => _fabExtended = extended);
    return false;
  }

  // Grouping cache so the list is not regrouped on every rebuild.
  List<ExpenseEntity>? _groupSource;
  ExpenseSortOption? _groupSort;
  List<ExpenseGroup> _groups = const [];

  /// Rows that entered the list with the latest data change, in display
  /// order. Only these play the slide-in: rows that merely scroll into view
  /// or arrive with a "load more" page render immediately, so the list never
  /// shows blank rows while the user is flinging.
  Map<String, int> _entering = const {};
  List<ExpenseEntity>? _enteringSource;
  List<ExpenseEntity>? _enteringVisible;
  Set<String> _knownIds = const {};

  /// Last filter/sort/query the list was built for, to scroll back to the
  /// top when they change so the user never lands mid-way through a
  /// different list.
  ExpenseHistoryFilter? _builtFilter;
  ExpenseSortOption? _builtSort;
  String? _builtQuery;

  @override
  void initState() {
    super.initState();
    context.read<ExpenseHistoryBloc>().add(const ExpenseHistoryLoad());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final bloc = context.read<ExpenseHistoryBloc>();
    if (!bloc.state.hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      bloc.add(const ExpenseHistoryLoadMore());
    }
  }

  List<ExpenseGroup> _groupsFor(ExpenseHistoryState state) {
    if (!identical(_groupSource, state.loadedExpenses) ||
        _groupSort != state.sort) {
      _groupSource = state.loadedExpenses;
      _groupSort = state.sort;
      _groups = _groupExpensesUseCase(state.loadedExpenses, sort: state.sort);
    }
    return _groups;
  }

  /// Works out which rows are new since the previous list. A page appended
  /// by "load more" leaves [ExpenseHistoryState.visibleExpenses] untouched,
  /// so its rows are treated as already known.
  void _trackEntering(ExpenseHistoryState state) {
    if (identical(_enteringSource, state.loadedExpenses)) return;
    final loaded = state.loadedExpenses;
    final ids = <String>{for (final e in loaded) e.id};
    final isPagination =
        _enteringVisible != null &&
        identical(_enteringVisible, state.visibleExpenses);
    if (isPagination) {
      _entering = const {};
    } else {
      var i = 0;
      _entering = {
        for (final e in loaded)
          if (!_knownIds.contains(e.id)) e.id: i++,
      };
    }
    _knownIds = ids;
    _enteringSource = loaded;
    _enteringVisible = state.visibleExpenses;
  }

  /// Scrolls to the top when the list is about to show different content
  /// (a new filter, sort or search), never on a plain refresh.
  void _resetScrollIfCriteriaChanged(ExpenseHistoryState state) {
    final changed =
        _builtFilter != null &&
        (_builtFilter != state.filter ||
            _builtSort != state.sort ||
            _builtQuery != state.query);
    _builtFilter = state.filter;
    _builtSort = state.sort;
    _builtQuery = state.query;
    if (changed) {
      // Called from build; move the scroll view once the frame is laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }
  }

  /// Cached id → category lookup, rebuilt only when the list identity
  /// changes. A linear scan per row is cheap but runs on every row of every
  /// rebuild; the state already keeps a map for budgets.
  List<ExpenseCategory>? _categoriesSource;
  Map<String, ExpenseCategory> _categoryById = const {};

  ExpenseCategory? _findCategory(List<ExpenseCategory> categories, String id) {
    if (!identical(_categoriesSource, categories)) {
      _categoriesSource = categories;
      _categoryById = {for (final c in categories) c.id: c};
    }
    return _categoryById[id];
  }

  Future<void> _openFilterSheet() async {
    final bloc = context.read<ExpenseHistoryBloc>();
    final result = await showFilterBottomSheet(
      context,
      current: bloc.state.filter,
      categories: bloc.state.categories,
    );
    if (result != null && mounted) {
      bloc.add(ExpenseHistoryFilterChanged(result));
    }
  }

  Future<void> _openSortSheet() async {
    final bloc = context.read<ExpenseHistoryBloc>();
    final result = await showSortBottomSheet(context, current: bloc.state.sort);
    if (result != null && mounted) {
      bloc.add(ExpenseHistorySortChanged(result));
    }
  }

  /// Deletes right away and lets the SnackBar offer "Undo" — no dialog.
  ///
  /// The row is dropped from the list first so it is gone in the same frame;
  /// the real delete follows and its refresh confirms the list. Undo
  /// restores the expense, which then slides back in as a new row.
  void _deleteWithUndo(ExpenseEntity expense) {
    final expenseBloc = context.read<ExpenseBloc?>();
    if (expenseBloc == null) return;
    context.read<ExpenseHistoryBloc>().add(
      ExpenseHistoryExpenseRemoved(expense.id),
    );
    expenseBloc.add(ExpenseDelete(expense.id));
  }

  /// Whether a swiped row may leave. The delete itself happens once the row
  /// has finished animating out (see [_buildDismissibleRow]); deleting here
  /// would refresh the list mid-animation and make the rows below jump.
  Future<bool> _confirmDismiss(ExpenseEntity expense) async {
    if (context.read<ExpenseBloc?>() == null) return false;
    HapticFeedback.mediumImpact();
    return true;
  }

  Future<void> _showRowActions(
    ExpenseEntity expense,
    ExpenseCategory? category,
    BudgetEntity? budget,
  ) async {
    HapticFeedback.selectionClick();
    final action = await ExpenseActionsSheet.show(
      context,
      expense: expense,
      category: category,
      currency:
          budget?.currency ??
          context.read<ExpenseHistoryBloc>().state.budgetCurrency,
    );
    if (action == null || !mounted) return;
    switch (action) {
      case ExpenseRowAction.edit:
        context.pushUnique('/app/expenses/edit/${expense.id}');
      case ExpenseRowAction.duplicate:
        context.pushUnique('/app/expenses/add?copy=${expense.id}');
      case ExpenseRowAction.move:
        final expenseBloc = context.read<ExpenseBloc?>();
        final target = await MoveExpenseSheet.show(context, expense: expense);
        if (target == null || !mounted || expenseBloc == null) return;
        expenseBloc.add(
          ExpenseUpdate(
            expense.copyWith(budgetId: target.id, updatedAt: DateTime.now()),
          ),
        );
      case ExpenseRowAction.delete:
        HapticFeedback.mediumImpact();
        _deleteWithUndo(expense);
    }
  }

  /// Enters combined mode: makes sure budgets are loaded, lets the user pick
  /// which budgets to view together, then applies the selection.
  Future<void> _chooseCombinedBudgets() async {
    final bloc = context.read<ExpenseHistoryBloc>();
    final wasCombined = bloc.state.isCombinedMode;

    if (bloc.state.allBudgets.isEmpty) {
      bloc.add(const ExpenseHistoryToggleViewMode());
      try {
        await bloc.stream
            .firstWhere((s) => s.allBudgets.isNotEmpty)
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        if (!mounted) return;
        bloc.add(const ExpenseHistoryExitCombinedView());
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('You need at least one budget to combine.'),
            ),
          );
        return;
      }
    } else if (!wasCombined) {
      bloc.add(const ExpenseHistoryToggleViewMode());
    }
    if (!mounted) return;

    final selected = await BudgetSelectionSheet.show(
      context: context,
      allBudgets: bloc.state.allBudgets,
      initiallySelected: bloc.state.selectedBudgetIds,
    );
    if (!mounted) return;

    if (selected == null) {
      // Cancelled without a usable selection: fall back to the active budget.
      if (bloc.state.selectedBudgetIds.isEmpty) {
        bloc.add(const ExpenseHistoryExitCombinedView());
      }
      return;
    }
    bloc.add(ExpenseHistorySetBudgetSelection(selected));
    bloc.add(const ExpenseHistoryApplyCombinedView());
  }

  void _exitCombined() {
    _searchController.clear();
    context.read<ExpenseHistoryBloc>().add(
      const ExpenseHistoryExitCombinedView(),
    );
  }

  Future<void> _refresh() async {
    final bloc = context.read<ExpenseHistoryBloc>();
    bloc.add(const ExpenseHistoryRefresh());
    await bloc.stream
        .firstWhere((s) => s.status != ExpenseHistoryStatus.refreshing)
        .timeout(const Duration(seconds: 8), onTimeout: () => bloc.state);
  }

  @override
  Widget build(BuildContext context) {
    // ExpenseBloc drives create/update/delete. It is provided by the route;
    // fall back gracefully when absent (e.g. isolated widget tests).
    final expenseBloc = context.read<ExpenseBloc?>();

    Widget body = SafeArea(
      bottom: false,
      child: BlocConsumer<ExpenseHistoryBloc, ExpenseHistoryState>(
        // The query lands in state on every keystroke but the list only
        // changes when the debounce fires, so rebuilding the rows on each
        // character was pure waste. The search field is driven by its own
        // controller.
        buildWhen: (prev, curr) =>
            prev.status != curr.status ||
            !identical(prev.visibleExpenses, curr.visibleExpenses) ||
            !identical(prev.loadedExpenses, curr.loadedExpenses) ||
            !identical(prev.categories, curr.categories) ||
            prev.summary != curr.summary ||
            prev.summaryByCurrency != curr.summaryByCurrency ||
            prev.filter != curr.filter ||
            prev.viewMode != curr.viewMode ||
            prev.selectedBudgetIds != curr.selectedBudgetIds ||
            prev.budgetMap != curr.budgetMap ||
            prev.budgetName != curr.budgetName ||
            prev.budgetCurrency != curr.budgetCurrency ||
            prev.errorMessage != curr.errorMessage,
        listenWhen: (prev, curr) =>
            curr.status == ExpenseHistoryStatus.error &&
            prev.status != ExpenseHistoryStatus.error,
        listener: (context, state) {
          // The full error view handles the empty case; otherwise surface
          // the failure without hiding the data on screen.
          if (state.allExpenses.isNotEmpty) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    state.errorMessage ?? "Couldn't refresh expenses",
                  ),
                ),
              );
          }
        },
        builder: (context, state) => _buildScroll(context, state),
      ),
    );
    body = NotificationListener<UserScrollNotification>(
      onNotification: _onUserScroll,
      child: body,
    );

    if (expenseBloc != null) {
      body = BlocListener<ExpenseBloc, ExpenseState>(
        bloc: expenseBloc,
        listenWhen: (prev, curr) =>
            prev.status != curr.status &&
            (curr.status == ExpenseBlocStatus.success ||
                curr.status == ExpenseBlocStatus.error) &&
            curr.message != null,
        listener: (context, state) {
          final deleted = state.lastAction == ExpenseAction.deleted
              ? state.lastDeleted
              : null;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                key: deleted != null ? const Key('undoDeleteSnackBar') : null,
                content: Text(_quietMessage(state)),
                duration: deleted != null
                    ? const Duration(seconds: 6)
                    : const Duration(seconds: 4),
                action: deleted != null
                    ? SnackBarAction(
                        key: const Key('undoDeleteAction'),
                        label: 'Undo',
                        onPressed: () =>
                            expenseBloc.add(ExpenseRestore(deleted)),
                      )
                    : null,
              ),
            );
          expenseBloc.add(const ExpenseClearMessage());
        },
        child: body,
      );
    }

    return Scaffold(
      body: body,
      floatingActionButton: AppFab(
        heroTag: 'expenses_fab',
        onPressed: () => QuickAddSheet.show(context),
        icon: Icons.add_rounded,
        label: 'Add expense',
        tooltip: 'Add expense',
        extended: _fabExtended,
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  /// The title, the budget menu under it, and info, filter and sort.
  Widget _buildHeader(ExpenseHistoryState state) {
    final theme = Theme.of(context);
    final caption = state.isCombinedMode
        ? 'Each expense keeps its own budget'
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // With very large text the title shrinks to fit beside the
                // buttons rather than breaking mid-word.
                Semantics(
                  header: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'Expenses',
                      style: theme.textTheme.headlineSmall,
                      maxLines: 1,
                    ),
                  ),
                ),
                _BudgetMenu(
                  state: state,
                  onSwitchBudget: () => ActiveBudgetSelector.open(context),
                  onCombine: _chooseCombinedBudgets,
                  onSingle: _exitCombined,
                ),
                if (caption != null)
                  Text(
                    caption,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          InfoIcon(content: _expenseListInfo(state)),
          IconButton(
            key: const Key('filterButton'),
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: 'Filter expenses',
            onPressed: _openFilterSheet,
          ),
          IconButton(
            key: const Key('sortButton'),
            icon: const Icon(Icons.swap_vert_rounded),
            tooltip: 'Sort expenses',
            onPressed: _openSortSheet,
          ),
        ],
      ),
    );
  }

  // ── Scroll view ──────────────────────────────────────────────────────────

  Widget _buildScroll(BuildContext context, ExpenseHistoryState state) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        key: const ValueKey('loaded'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(state)),
          SliverToBoxAdapter(
            child: ExpenseSearchBar(
              controller: _searchController,
              onChanged: (query) => context.read<ExpenseHistoryBloc>().add(
                ExpenseHistorySearchChanged(query),
              ),
              onClear: () => context.read<ExpenseHistoryBloc>().add(
                const ExpenseHistorySearchChanged(''),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: QuickFilterChips(
              current: state.filter,
              categories: state.categories,
              onSelected: (filter) => context.read<ExpenseHistoryBloc>().add(
                ExpenseHistoryFilterChanged(filter),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AppAnimatedSize(
              duration: AppMotion.respectReducedMotion(
                context,
                AppMotion.standard,
              ),
              curve: AppMotion.standardCurve,
              alignment: Alignment.topCenter,
              child: ActiveFilterChips(
                filter: state.filter,
                categories: state.categories,
                onChanged: (filter) => context.read<ExpenseHistoryBloc>().add(
                  ExpenseHistoryFilterChanged(filter),
                ),
              ),
            ),
          ),
          ..._buildResults(context, state),
        ],
      ),
    );
  }

  /// The controls above stay put; only this part switches between
  /// skeleton, error, empty and the list, so a load never makes the
  /// controls disappear and reappear.
  List<Widget> _buildResults(BuildContext context, ExpenseHistoryState state) {
    final Widget? child;
    final neverLoaded =
        state.status == ExpenseHistoryStatus.initial ||
        (state.status == ExpenseHistoryStatus.loading &&
            state.allExpenses.isEmpty);
    if (neverLoaded) {
      // Local data usually arrives first; the skeleton only shows when it
      // does not.
      child = const DelayedReveal(
        key: ValueKey('loading'),
        child: ExpenseListSkeleton(),
      );
    } else if (state.status == ExpenseHistoryStatus.error &&
        state.allExpenses.isEmpty) {
      child = ExpenseHistoryErrorWidget(
        key: const ValueKey('error'),
        message: state.errorMessage ?? "Couldn't load expenses",
        onRetry: () => context.read<ExpenseHistoryBloc>().add(
          const ExpenseHistoryRefresh(),
        ),
      );
    } else if (state.isEmpty) {
      child = ExpenseHistoryEmptyState(
        key: const ValueKey('empty'),
        hasAnyExpenses: state.allExpenses.isNotEmpty,
        hasSearchQuery: state.query.isNotEmpty,
        hasActiveFilters: state.filter.isActive,
        onAddFirst: () => QuickAddSheet.show(context),
        onClearFilters: () {
          _searchController.clear();
          context.read<ExpenseHistoryBloc>().add(
            const ExpenseHistoryClearFilters(),
          );
        },
      );
    } else {
      child = null;
    }
    if (child != null) {
      return [SliverFillRemaining(child: AppStateSwitcher(child: child))];
    }
    return _buildList(context, state);
  }

  List<Widget> _buildList(BuildContext context, ExpenseHistoryState state) {
    _trackEntering(state);
    _resetScrollIfCriteriaChanged(state);
    final groups = _groupsFor(state);
    final count = state.summary.totalExpenses;
    final summaryCaption = state.isCombinedMode
        ? 'Across ${state.selectedBudgetIds.length} budgets · '
              '$count ${count == 1 ? 'expense' : 'expenses'}'
        : null;

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        sliver: SliverList.builder(
          key: const ValueKey('list'),
          itemCount: groups.length + 2,
          // Day groups are keyed so a new "Today" group (or a day emptied by
          // a delete) never hands another day's element, and its total, to
          // the wrong date.
          findChildIndexCallback: (key) {
            if (key is! ValueKey<String>) return null;
            final value = key.value;
            if (value == 'summary') return 0;
            if (value == 'loadMore') return groups.length + 1;
            for (var i = 0; i < groups.length; i++) {
              if (_groupKey(groups[i]) == value) return i + 1;
            }
            return null;
          },
          itemBuilder: (context, index) {
            if (index == 0) {
              return SummaryCard(
                key: const ValueKey('summary'),
                summary: state.summary,
                currency: state.displayCurrency,
                caption: summaryCaption,
                byCurrency: state.summaryByCurrency,
              );
            }
            if (index == groups.length + 1) {
              return LoadingMoreIndicator(
                key: const ValueKey('loadMore'),
                hasMore: state.hasMore,
                isLoading: state.status == ExpenseHistoryStatus.loadingMore,
              );
            }
            return _buildGroup(context, groups[index - 1], state, index - 1);
          },
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: AppSizes.fabClearance)),
    ];
  }

  /// The one currency a day's total can be shown in: the screen's, or for a
  /// combined view that mixes currencies, the day's own when all of its
  /// expenses share one. Null means the day gets no total.
  (bool, String?) _groupTotalCurrency(
    ExpenseGroup group,
    ExpenseHistoryState state,
  ) {
    if (!state.mixesCurrencies) return (true, state.displayCurrency);
    final codes = {
      for (final e in group.expenses) state.budgetMap[e.budgetId]?.currency,
    };
    if (codes.length == 1 && codes.single != null) return (true, codes.single);
    return (false, null);
  }

  Widget _buildGroup(
    BuildContext context,
    ExpenseGroup group,
    ExpenseHistoryState state,
    int groupIndex,
  ) {
    final theme = Theme.of(context);
    final (showTotal, currency) = _groupTotalCurrency(group, state);
    // Date headers stay put; only the rows animate.
    return Column(
      key: ValueKey<String>(_groupKey(group)),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExpenseGroupHeader(
          group: group,
          currency: currency,
          showTotal: showTotal,
        ),
        for (var i = 0; i < group.expenses.length; i++) ...[
          if (i > 0)
            Divider(
              key: ValueKey('div_${group.expenses[i].id}'),
              indent: AppSizes.avatarSm + AppSpacing.smd,
              color: theme.colorScheme.outlineVariant,
            ),
          _buildExpenseRow(context, group.expenses[i], state),
        ],
      ],
    );
  }

  static String _groupKey(ExpenseGroup group) {
    final date = group.date;
    if (date == null) return 'group_${group.type.name}';
    return 'group_${date.year}-${date.month}-${date.day}';
  }

  Widget _buildExpenseRow(
    BuildContext context,
    ExpenseEntity expense,
    ExpenseHistoryState state,
  ) {
    final category = _findCategory(state.categories, expense.categoryId);
    final budget = state.isCombinedMode
        ? state.budgetMap[expense.budgetId]
        : null;
    final currency = budget?.currency ?? state.budgetCurrency;
    final enterIndex = _entering[expense.id];

    return FadeSlideIn(
      key: ValueKey('enter_${expense.id}'),
      animate: enterIndex != null,
      // Stagger by arrival order (a handful of new rows cascade briefly),
      // not by position in the whole list.
      index: enterIndex ?? 0,
      child: _buildDismissibleRow(
        context,
        expense,
        state,
        category,
        budget,
        currency,
      ),
    );
  }

  Widget _buildDismissibleRow(
    BuildContext context,
    ExpenseEntity expense,
    ExpenseHistoryState state,
    ExpenseCategory? category,
    BudgetEntity? budget,
    String? currency,
  ) {
    final dismissDuration = AppMotion.respectReducedMotion(
      context,
      AppMotion.standard,
    );
    return Dismissible(
      key: Key('dismiss_${expense.id}'),
      direction: DismissDirection.endToStart,
      movementDuration: dismissDuration,
      resizeDuration: dismissDuration,
      confirmDismiss: (_) => _confirmDismiss(expense),
      onDismissed: (_) => _deleteWithUndo(expense),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: context.appColors.error,
          borderRadius: AppSpacing.borderRadiusSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Delete',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onError,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.delete_rounded,
              color: Theme.of(context).colorScheme.onError,
            ),
          ],
        ),
      ),
      child: ExpenseHistoryItem(
        expense: expense,
        category: category,
        budgetName: budget?.name,
        currency: currency,
        onInfoTap: state.isCombinedMode
            ? () => BudgetInfoBottomSheet.show(
                context: context,
                expense: expense,
                budget: budget,
                categoryName: category?.name,
              )
            : null,
        onTap: () => context.pushUnique('/app/expenses/${expense.id}'),
        onLongPress: () => _showRowActions(expense, category, budget),
      ),
    );
  }

  /// Short confirmations, the same words the other screens use.
  static String _quietMessage(ExpenseState state) {
    if (state.status != ExpenseBlocStatus.success) return state.message!;
    return switch (state.lastAction) {
      ExpenseAction.created => 'Expense added',
      ExpenseAction.updated => 'Expense updated',
      ExpenseAction.deleted => 'Expense deleted',
      ExpenseAction.restored => 'Expense restored',
      ExpenseAction.none => state.message!,
    };
  }

  // ── Info copy ────────────────────────────────────────────────────────────

  InfoContent _expenseListInfo(ExpenseHistoryState state) {
    if (state.isCombinedMode) {
      return const InfoContent(
        title: 'Combined Expenses',
        whatIsThis:
            'One list showing the expenses of every budget you selected, '
            'so you can compare or review them together. Your budgets '
            'themselves are not merged: each keeps its own amount, period '
            "and Today's Safe Spending.",
        howIsItCalculated:
            'Expenses from the selected budgets are loaded into a single '
            'list, then grouped by date (newest day first) and sorted with '
            'the sort option you choose. The summary total is the sum of '
            'the expenses shown after search and filters.',
        additionalNotes:
            '• Every expense still belongs to its original budget. The tag '
            'on each row shows which one\n'
            "• Tap the info icon on a row to see the expense's budget, "
            'category, amount, date and time\n'
            '• Only budgets that are not archived can be selected\n'
            '• Search, filters and sorting work across all selected budgets\n'
            '• Open the budget menu under the title to change the budgets '
            'or go back to your active budget',
      );
    }
    return const InfoContent(
      title: 'Expenses',
      whatIsThis:
          'All expenses recorded in your active budget. Switch the active '
          "budget from the Dashboard or Budgets to see a different budget's "
          'expenses.',
      howIsItCalculated:
          'Expenses are grouped by the day they were recorded, newest day '
          'first. Within each day they follow the sort option you choose: '
          'newest or oldest first, highest or lowest amount, category, or '
          'note text (A to Z). The summary counts only the expenses '
          'currently shown.',
      additionalNotes:
          '• Each expense belongs to exactly one budget and counts toward '
          "that budget's remaining amount and Today's Safe Spending\n"
          '• Use search, quick filters and the filter sheet to narrow the '
          'list\n'
          '• Open the budget menu under the title to view several budgets '
          'together\n'
          '• Swipe an expense left to delete it — Undo is offered for a few '
          'seconds\n'
          '• Press and hold an expense to edit, duplicate, move or delete it',
    );
  }
}

enum _BudgetMenuAction { switchBudget, combine, single }

/// The budget the list follows, under the title, as a menu: switch the
/// active budget, view several budgets together, or go back to one.
class _BudgetMenu extends StatelessWidget {
  final ExpenseHistoryState state;
  final VoidCallback onSwitchBudget;
  final VoidCallback onCombine;
  final VoidCallback onSingle;

  const _BudgetMenu({
    required this.state,
    required this.onSwitchBudget,
    required this.onCombine,
    required this.onSingle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final combined = state.isCombinedMode;
    final label = combined
        ? (state.selectedBudgetsLabel.isEmpty
              ? 'Choose budgets'
              : state.selectedBudgetsLabel)
        : (state.budgetName ?? 'No active budget');
    return PopupMenuButton<_BudgetMenuAction>(
      key: const Key('viewModeToggle'),
      tooltip: combined ? 'Budgets shown' : 'Budget shown',
      position: PopupMenuPosition.under,
      onSelected: (action) => switch (action) {
        _BudgetMenuAction.switchBudget => onSwitchBudget(),
        _BudgetMenuAction.combine => onCombine(),
        _BudgetMenuAction.single => onSingle(),
      },
      itemBuilder: (context) => [
        if (!combined) ...[
          const PopupMenuItem(
            value: _BudgetMenuAction.switchBudget,
            child: ListTile(
              leading: Icon(Icons.swap_horiz_rounded),
              title: Text('Switch budget'),
            ),
          ),
          const PopupMenuItem(
            value: _BudgetMenuAction.combine,
            child: ListTile(
              leading: Icon(Icons.layers_outlined),
              title: Text('View budgets together'),
            ),
          ),
        ] else ...[
          const PopupMenuItem(
            value: _BudgetMenuAction.combine,
            child: ListTile(
              leading: Icon(Icons.checklist_rounded),
              title: Text('Change budgets'),
            ),
          ),
          const PopupMenuItem(
            value: _BudgetMenuAction.single,
            child: ListTile(
              leading: Icon(Icons.account_balance_wallet_outlined),
              title: Text('Back to the active budget'),
            ),
          ),
        ],
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (combined) ...[
              Icon(
                Icons.layers_rounded,
                size: AppSizes.iconSm,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
