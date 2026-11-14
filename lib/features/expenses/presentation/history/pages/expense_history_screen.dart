import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../budget/domain/entities/safe_to_spend/day_target.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constants/app_motion.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/feedback/app_haptics.dart';
import '../../../../../core/theme/app_colors_extension.dart';
import '../../../../../core/widgets/app_snack.dart';
import '../../../../../core/widgets/app_state_switcher.dart';
import '../../../../../core/widgets/info_content.dart';
import '../../../../../core/widgets/info_icon.dart';
import '../../../../../core/widgets/loading_skeleton.dart';
import '../../../domain/entities/activity_extra.dart';
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
import '../widgets/activity_extra_row.dart';
import '../widgets/activity_switch.dart';
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
import '../../widgets/expense_undo.dart';
import '../../widgets/move_expense_sheet.dart';
import '../../widgets/paid_bill.dart';
import '../widgets/summary_card.dart';
import '../../quick_add/quick_add_sheet.dart';
import '../../../../budget/presentation/widgets/active_budget_selector.dart';
import '../../../../../core/domain/entities/budget_entity.dart';
import '../../../../../core/widgets/fade_slide_in.dart';
import '../../../../../core/navigation/push_unique.dart';
import '../../../../../core/dates/calendar_dates.dart';
import '../../../../../core/router/app_router.dart';
import '../../../../../core/widgets/app_animated_size.dart';
import '../../../../../core/widgets/app_page_body.dart';
import '../../../../pay_later/domain/entities/purchase_change_impact.dart';
import '../../../../pay_later/presentation/widgets/purchase_impact_dialog.dart';

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

  /// The search field is open (blueprint: a search button in the header).
  bool _searching = false;

  void _openSearch() => setState(() => _searching = true);
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

  /// The currency the amount filter is in: the budget's, or the one every
  /// selected budget shares. Null when the selection mixes currencies: the
  /// bounds then apply to each amount in its own currency.
  String? _filterCurrency(ExpenseHistoryState state) {
    if (!state.isCombinedMode) return state.budgetCurrency;
    final codes = {
      for (final id in state.selectedBudgetIds) state.budgetMap[id]?.currency,
    };
    return codes.length == 1 ? codes.single : null;
  }

  Future<void> _openSortSheet() async {
    final bloc = context.read<ExpenseHistoryBloc>();
    final result = await showSortBottomSheet(context, current: bloc.state.sort);
    if (result != null && mounted) {
      bloc.add(ExpenseHistorySortChanged(result));
    }
  }

  /// Swipes per expense, part of its row's key: a row that comes back (its
  /// delete failed) needs a fresh Dismissible, not the one already dismissed.
  final Map<String, int> _swipes = {};

  /// Swiped rows the user confirmed through the payments dialog, so their
  /// delete offers no Undo.
  final Set<String> _confirmedDeletes = {};

  /// Deletes right away and lets the SnackBar offer "Undo" — no dialog.
  /// [undoable] is false for a tab purchase whose delete the user already
  /// confirmed (it moved payment money), which offers no Undo.
  ///
  /// The row is dropped from the list first so it is gone in the same frame;
  /// the real delete follows and its refresh confirms the list. Undo
  /// restores the expense, which then slides back in as a new row.
  void _deleteWithUndo(ExpenseEntity expense, {bool undoable = true}) {
    final expenseBloc = context.read<ExpenseBloc?>();
    if (expenseBloc == null) return;
    _swipes[expense.id] = (_swipes[expense.id] ?? 0) + 1;
    context.read<ExpenseHistoryBloc>().add(
      ExpenseHistoryExpenseRemoved(expense.id),
    );
    expenseBloc.add(ExpenseDelete(expense.id, undoable: undoable));
  }

  /// The budget a move from the actions is heading to and the expense as
  /// it was, for "Moved to … · Undo".
  ({String name, ExpenseEntity original})? _moving;

  /// Expenses whose delete is being checked or confirmed right now.
  final Set<String> _deleteChecks = {};

  /// Before deleting [expense]: a tab purchase with payment money on it
  /// says where that money goes and asks. Null when the delete must not
  /// happen (cancelled, its payments couldn't be checked, or a delete of
  /// it is already being checked); otherwise whether the delete may offer
  /// Undo.
  Future<bool?> _askBeforeDelete(
    ExpenseBloc expenseBloc,
    ExpenseEntity expense,
  ) async {
    // A second swipe or long-press while the first is still checking (or
    // its dialog is open) must not start another delete.
    if (!_deleteChecks.add(expense.id)) return null;
    try {
      return await _checkPaymentsBeforeDelete(expenseBloc, expense);
    } finally {
      _deleteChecks.remove(expense.id);
    }
  }

  Future<bool?> _checkPaymentsBeforeDelete(
    ExpenseBloc expenseBloc,
    ExpenseEntity expense,
  ) async {
    final PurchaseChangeImpact? impact;
    try {
      impact = await expenseBloc.tabPurchases.impactOf(
        expense.id,
        deleting: true,
      );
    } catch (e) {
      debugPrint('[error] Checking payments before deleting an expense: $e');
      if (mounted) {
        AppSnack.show(context, PurchaseImpactDialog.deleteCheckFailed);
      }
      return null;
    }
    if (!mounted) return null;
    if (impact == null || !impact.touchesPayments) return true;
    final confirmed = await PurchaseImpactDialog.show(
      context,
      impact: impact,
      deleting: true,
    );
    return confirmed ? false : null;
  }

  /// Whether a swiped row may leave. The delete itself happens once the row
  /// has finished animating out (see [_buildDismissibleRow]); deleting here
  /// would refresh the list mid-animation and make the rows below jump.
  Future<bool> _confirmDismiss(ExpenseEntity expense) async {
    final expenseBloc = context.read<ExpenseBloc?>();
    if (expenseBloc == null) return false;
    AppHaptics.threshold();
    final undoable = await _askBeforeDelete(expenseBloc, expense);
    if (undoable == null || !mounted) return false;
    if (!undoable) _confirmedDeletes.add(expense.id);
    return true;
  }

  Future<void> _showRowActions(
    ExpenseEntity expense,
    ExpenseCategory? category,
    BudgetEntity? budget,
  ) async {
    AppHaptics.selection();
    // Whether there is anywhere to move it, and the bill a payment paid.
    // Either may be unreadable; the sheet still opens.
    final (budgets, billTitle) = await (
      MoveExpenseSheet.loadBudgets(),
      PaidBill.titleOf(expense),
    ).wait;
    if (!mounted) return;
    final action = await ExpenseActionsSheet.show(
      context,
      expense: expense,
      category: category,
      currency:
          budget?.currency ??
          context.read<ExpenseHistoryBloc>().state.budgetCurrency,
      canMove: budgets == null || MoveExpenseSheet.hasTarget(budgets, expense),
      billTitle: billTitle,
    );
    if (action == null || !mounted) return;
    switch (action) {
      case ExpenseRowAction.edit:
        context.pushUnique('/app/expenses/edit/${expense.id}');
      case ExpenseRowAction.duplicate:
        context.pushUnique('/app/expenses/add?copy=${expense.id}');
      case ExpenseRowAction.move:
        final expenseBloc = context.read<ExpenseBloc?>();
        final target = await MoveExpenseSheet.show(
          context,
          expense: expense,
          budgets: budgets,
          billTitle: billTitle,
        );
        if (target == null || !mounted || expenseBloc == null) return;
        _moving = (name: target.name, original: expense);
        expenseBloc.add(
          ExpenseUpdate(
            expense.copyWith(budgetId: target.id, updatedAt: DateTime.now()),
          ),
        );
      case ExpenseRowAction.delete:
        final expenseBloc = context.read<ExpenseBloc?>();
        if (expenseBloc == null) return;
        final undoable = await _askBeforeDelete(expenseBloc, expense);
        if (undoable == null || !mounted) return;
        AppHaptics.confirm();
        _deleteWithUndo(expense, undoable: undoable);
    }
  }

  /// Enters combined mode: makes sure budgets are loaded, lets the user pick
  /// which budgets to view together, then applies the selection.
  Future<void> _chooseCombinedBudgets() async {
    final bloc = context.read<ExpenseHistoryBloc>();
    final wasCombined = bloc.state.isCombinedMode;

    if (!wasCombined) {
      // Entering the combined view re-reads the budgets; wait for them.
      bloc.add(const ExpenseHistoryToggleViewMode());
      var load = BudgetsLoad.failed;
      try {
        final read = await bloc.stream
            .firstWhere(
              (s) =>
                  s.budgetsLoad == BudgetsLoad.loaded ||
                  s.budgetsLoad == BudgetsLoad.failed,
            )
            .timeout(const Duration(seconds: 5));
        load = read.budgetsLoad;
      } on TimeoutException catch (e) {
        debugPrint('[error] Loading budgets to view together: $e');
      }
      if (!mounted) return;
      if (load == BudgetsLoad.failed || bloc.state.allBudgets.isEmpty) {
        bloc.add(const ExpenseHistoryExitCombinedView());
        AppSnack.show(
          context,
          load == BudgetsLoad.failed
              ? "Couldn't load your budgets. Try again."
              : 'You need at least one budget to combine.',
        );
        return;
      }
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
            prev.extras != curr.extras ||
            // Tab payments and budget markers hide while searching.
            prev.query.isEmpty != curr.query.isEmpty ||
            prev.errorMessage != curr.errorMessage,
        listenWhen: (prev, curr) =>
            curr.status == ExpenseHistoryStatus.error &&
            prev.status != ExpenseHistoryStatus.error,
        listener: (context, state) {
          // The full error view handles the empty case; otherwise surface
          // the failure without hiding the data on screen.
          if (state.allExpenses.isNotEmpty) {
            AppSnack.show(
              context,
              state.errorMessage == null ||
                      state.errorMessage == ExpenseHistoryBloc.loadFailedMessage
                  ? "Couldn't refresh expenses. Try again in a moment."
                  : state.errorMessage!,
            );
          }
        },
        builder: (context, state) => _buildScroll(context, state),
      ),
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
          final moving = _moving;
          _moving = null;
          if (moving != null &&
              state.status == ExpenseBlocStatus.success &&
              state.lastAction == ExpenseAction.updated) {
            ExpenseUndo.offerMoved(
              ScaffoldMessenger.of(context),
              moving.original,
              to: moving.name,
            );
            expenseBloc.add(const ExpenseClearMessage());
            return;
          }
          // A swiped row leaves the list before its delete runs; when the
          // delete fails, read the list again so the row comes back.
          if (state.status == ExpenseBlocStatus.error) {
            context.read<ExpenseHistoryBloc>().add(
              const ExpenseHistoryRefresh(),
            );
          }
          final deleted = state.lastAction == ExpenseAction.deleted
              ? state.lastDeleted
              : null;
          final link = state.lastDeletedLink;
          AppSnack.present(
            ScaffoldMessenger.of(context),
            deleted != null
                ? ExpenseUndo.snackBar(
                    message: _quietMessage(state),
                    onUndo: () =>
                        expenseBloc.add(ExpenseRestore(deleted, link: link)),
                  )
                : AppSnack.bar(_quietMessage(state)),
          );
          expenseBloc.add(const ExpenseClearMessage());
        },
        child: body,
      );
    }

    // Adding is the bar's + (AppShell).
    return Scaffold(body: body);
  }

  // ── Header ───────────────────────────────────────────────────────────────

  /// The title, the budget menu under it, and info, filter and sort.
  Widget _buildHeader(ExpenseHistoryState state) {
    final theme = Theme.of(context);
    final caption = state.isCombinedMode
        ? 'Each expense keeps its own budget'
        : null;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
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
                      'Activity',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
                // Blueprint: the title alone; the budgets shown are named
                // only when several are viewed together.
                if (state.isCombinedMode)
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
          // Blueprint header: search and filter; sort, the budget and the
          // info sheet are one tap further, in the menu.
          IconButton(
            key: const Key('searchButton'),
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search expenses',
            onPressed: _openSearch,
          ),
          IconButton(
            key: const Key('filterButton'),
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: 'Filter expenses',
            onPressed: _openFilterSheet,
          ),
          PopupMenuButton<_HeaderAction>(
            key: const Key('activityMenu'),
            tooltip: 'More options',
            position: PopupMenuPosition.under,
            onSelected: (action) => switch (action) {
              _HeaderAction.sort => _openSortSheet(),
              _HeaderAction.switchBudget => ActiveBudgetSelector.open(context),
              _HeaderAction.combine => _chooseCombinedBudgets(),
              _HeaderAction.info => InfoIcon.showSheet(
                context,
                _expenseListInfo(state),
              ),
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                key: Key('sortButton'),
                value: _HeaderAction.sort,
                child: ListTile(
                  leading: Icon(Icons.swap_vert_rounded),
                  title: Text('Sort'),
                ),
              ),
              if (!state.isCombinedMode) ...[
                PopupMenuItem(
                  key: const Key('viewModeToggle'),
                  value: _HeaderAction.switchBudget,
                  child: ListTile(
                    leading: const Icon(Icons.swap_horiz_rounded),
                    title: const Text('Switch budget'),
                    subtitle: state.budgetName == null
                        ? null
                        : Text('Showing ${state.budgetName}'),
                  ),
                ),
                const PopupMenuItem(
                  value: _HeaderAction.combine,
                  child: ListTile(
                    leading: Icon(Icons.layers_outlined),
                    title: Text('View budgets together'),
                  ),
                ),
              ],
              const PopupMenuItem(
                value: _HeaderAction.info,
                child: ListTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('About this list'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Scroll view ──────────────────────────────────────────────────────────

  Widget _buildScroll(BuildContext context, ExpenseHistoryState state) {
    return RefreshIndicator(
      onRefresh: _refresh,
      // Each sliver keeps its own padding; the body only adds the gutters
      // that centre it on a tablet (the shell's bar clears the bottom).
      child: AppPageBody(
        padding: EdgeInsets.zero,
        builder: (context, padding) => CustomScrollView(
          key: const ValueKey('loaded'),
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            for (final sliver in <Widget>[
              SliverToBoxAdapter(child: _buildHeader(state)),
              // Blueprint: the stream and its insights, one switch apart.
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: ActivitySwitch(insights: false),
                ),
              ),
              if (_searching || state.query.isNotEmpty)
                SliverToBoxAdapter(
                  child: ExpenseSearchBar(
                    key: const Key('activitySearch'),
                    autofocus: _searching && state.query.isEmpty,
                    controller: _searchController,
                    onChanged: (query) => context
                        .read<ExpenseHistoryBloc>()
                        .add(ExpenseHistorySearchChanged(query)),
                    onClear: () {
                      context.read<ExpenseHistoryBloc>().add(
                        const ExpenseHistorySearchChanged(''),
                      );
                      setState(() => _searching = false);
                    },
                  ),
                ),
              SliverToBoxAdapter(
                child: QuickFilterChips(
                  current: state.filter,
                  categories: state.categories,
                  onSelected: (filter) => context
                      .read<ExpenseHistoryBloc>()
                      .add(ExpenseHistoryFilterChanged(filter)),
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
                    currency: _filterCurrency(state),
                    onChanged: (filter) => context
                        .read<ExpenseHistoryBloc>()
                        .add(ExpenseHistoryFilterChanged(filter)),
                  ),
                ),
              ),
              ..._buildResults(context, state),
            ])
              SliverPadding(
                padding: EdgeInsets.only(
                  left: padding.left,
                  right: padding.right,
                ),
                sliver: sliver,
              ),
          ],
        ),
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
      child = const ExpenseListSkeleton(key: ValueKey('loading'));
    } else if (state.status == ExpenseHistoryStatus.error &&
        state.allExpenses.isEmpty) {
      child = ExpenseHistoryErrorWidget(
        key: const ValueKey('error'),
        message: state.errorMessage ?? "Couldn't load expenses",
        onRetry: () => context.read<ExpenseHistoryBloc>().add(
          const ExpenseHistoryRefresh(),
        ),
      );
    } else if (state.isEmpty && _shownExtras(state).isEmpty) {
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

  /// The tab payments and budget markers the list shows: with no search
  /// and no filter but the kind, as the kind allows, and while more pages
  /// wait, only those on days already loaded (so none lands above rows
  /// still to come).
  static List<ActivityExtra> _shownExtras(ExpenseHistoryState state) {
    final items = state.extras.items;
    if (items.isEmpty || state.query.isNotEmpty) return const [];
    if (state.filter.copyWithKind(ExpenseKind.all).isActive) return const [];
    final kind = state.filter.kind;
    final loaded = state.loadedExpenses;
    final oldest = state.hasMore && loaded.isNotEmpty
        ? loaded
              .map((e) => e.date.dateOnly)
              .reduce((a, b) => a.isBefore(b) ? a : b)
        : null;
    return [
      for (final x in items)
        if ((kind == ExpenseKind.all ||
                (kind == ExpenseKind.payLater && x is TabPaymentExtra) ||
                (kind == ExpenseKind.budgets && x is BudgetMarkerExtra)) &&
            (oldest == null || !x.at.dateOnly.isBefore(oldest)))
          x,
    ];
  }

  /// The day groups with the extras of each day after its expenses
  /// (payments, then markers), and a group for a day with extras only.
  List<(ExpenseGroup, List<ActivityExtra>)> _sections(
    ExpenseHistoryState state,
  ) {
    final groups = _groupsFor(state);
    final shown = _shownExtras(state);
    if (shown.isEmpty) return [for (final g in groups) (g, const [])];
    final byDay = <DateTime, List<ActivityExtra>>{};
    for (final x in shown) {
      (byDay[x.at.dateOnly] ??= []).add(x);
    }
    for (final list in byDay.values) {
      list.sort((a, b) {
        if (a is TabPaymentExtra && b is TabPaymentExtra) {
          return b.at.compareTo(a.at);
        }
        return a is TabPaymentExtra ? -1 : (b is TabPaymentExtra ? 1 : 0);
      });
    }
    final today = DateTime.now().dateOnly;
    final sections = [
      for (final g in groups)
        (g, byDay.remove(g.date) ?? const <ActivityExtra>[]),
      for (final MapEntry(key: day, value: list) in byDay.entries)
        (
          ExpenseGroup(
            type: day == today
                ? ExpenseGroupType.today
                : day == today.addDays(-1)
                ? ExpenseGroupType.yesterday
                : ExpenseGroupType.earlier,
            date: day,
            expenses: const [],
          ),
          list,
        ),
    ];
    sections.sort((a, b) => b.$1.date!.compareTo(a.$1.date!));
    return sections;
  }

  List<Widget> _buildList(BuildContext context, ExpenseHistoryState state) {
    _trackEntering(state);
    _resetScrollIfCriteriaChanged(state);
    final sections = _sections(state);
    final groups = [for (final (g, _) in sections) g];
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
              // Only markers or payments shown (Budgets, Pay later with no
              // purchases): there are no expenses to sum.
              // Blueprint: no summary over the plain stream; it totals a
              // search or a filter's results.
              // A combined view keeps it: its per-currency totals are
              // nowhere else.
              if (state.visibleExpenses.isEmpty ||
                  (!state.isCombinedMode &&
                      state.query.isEmpty &&
                      !state.filter.isActive)) {
                return const SizedBox.shrink(key: ValueKey('summary'));
              }
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
            final (group, extras) = sections[index - 1];
            return _buildGroup(context, group, extras, state, index - 1);
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
    List<ActivityExtra> extras,
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
          dayTarget: _dayTargetFor(group, state),
          extraCount: extras.length,
        ),
        for (var i = 0; i < group.expenses.length; i++) ...[
          if (i > 0)
            Divider(
              key: ValueKey('div_${group.expenses[i].id}'),
              indent: AppSizes.avatarSm + AppSpacing.md,
              color: theme.colorScheme.outlineVariant,
            ),
          _buildExpenseRow(context, group.expenses[i], state),
        ],
        for (var i = 0; i < extras.length; i++) ...[
          if (i > 0 || group.expenses.isNotEmpty)
            Divider(
              indent: AppSizes.avatarSm + AppSpacing.md,
              color: theme.colorScheme.outlineVariant,
            ),
          ActivityExtraRow(
            key: ValueKey(_extraKey(extras[i])),
            extra: extras[i],
            onTap: switch (extras[i]) {
              TabPaymentExtra(:final tabId) => () => context.pushUnique(
                '${AppRouter.payLaterPath}/$tabId',
              ),
              BudgetMarkerExtra() => null,
            },
          ),
        ],
      ],
    );
  }

  /// The active budget's target for [group]'s day, in the single-budget
  /// view (a combined view mixes budgets, so no one target applies).
  static DayTarget? _dayTargetFor(
    ExpenseGroup group,
    ExpenseHistoryState state,
  ) {
    final date = group.date;
    if (date == null || state.isCombinedMode) return null;
    return state.dayTargets[DateTime(date.year, date.month, date.day)];
  }

  static String _extraKey(ActivityExtra x) => switch (x) {
    TabPaymentExtra(:final id) => 'tabPayment_$id',
    BudgetMarkerExtra(:final budgetId, :final started) =>
      'budget_${budgetId}_${started ? 'start' : 'end'}',
  };

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
      key: Key(
        _swipes.containsKey(expense.id)
            ? 'dismiss_${expense.id}_${_swipes[expense.id]}'
            : 'dismiss_${expense.id}',
      ),
      direction: DismissDirection.endToStart,
      movementDuration: dismissDuration,
      resizeDuration: dismissDuration,
      confirmDismiss: (_) => _confirmDismiss(expense),
      onDismissed: (_) => _deleteWithUndo(
        expense,
        undoable: !_confirmedDeletes.remove(expense.id),
      ),
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: AppSpacing.lg),
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
        tabName: state.extras.tabNameByExpense[expense.id],
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
        title: 'Combined expenses',
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
enum _HeaderAction { sort, switchBudget, combine, info }

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
