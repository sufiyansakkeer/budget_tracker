import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/widgets/app_header.dart';
import '../../../../../core/widgets/confirmation_dialog.dart';
import '../../../../../core/widgets/loading_skeleton.dart';
import '../../../domain/entities/expense_category.dart';
import '../../../domain/entities/expense_entity.dart';
import '../../../domain/entities/expense_group.dart';
import '../../../domain/usecases/group_expenses_usecase.dart';
import '../../bloc/expense_bloc.dart';
import '../../bloc/expense_event.dart';
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
import '../widgets/summary_card.dart';
import '../../../../../core/theme/app_colors_extension.dart';

/// Material 3 expense history screen with search, filters, sorting, grouping,
/// pagination, swipe actions, pull-to-refresh, and combined multi-budget view.
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
    final state = context.read<ExpenseHistoryBloc>().state;
    if (!state.hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ExpenseHistoryBloc>().add(const ExpenseHistoryLoadMore());
    }
  }

  ExpenseCategory? _findCategory(List<ExpenseCategory> categories, String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  Future<void> _openFilterSheet(ExpenseHistoryState state) async {
    final historyBloc = context.read<ExpenseHistoryBloc>();
    final result = await showFilterBottomSheet(
      context,
      current: state.filter,
      categories: state.categories,
    );
    if (result != null && mounted) {
      historyBloc.add(ExpenseHistoryFilterChanged(result));
    }
  }

  Future<void> _openSortSheet(ExpenseHistoryState state) async {
    final historyBloc = context.read<ExpenseHistoryBloc>();
    final result = await showSortBottomSheet(context, current: state.sort);
    if (result != null && mounted) {
      historyBloc.add(ExpenseHistorySortChanged(result));
    }
  }

  Future<bool> _confirmDelete(ExpenseEntity expense) async {
    final expenseBloc = context.read<ExpenseBloc>();
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Delete expense?',
      message:
          'This will permanently remove the expense of \u20b9${expense.amount}. '
          'This action cannot be undone.',
      confirmLabel: 'Delete',
      icon: Icons.delete_rounded,
      isDestructive: true,
    );
    if (confirmed && mounted) {
      expenseBloc.add(ExpenseDelete(expense.id));
    }
    return confirmed;
  }

  Future<void> _openBudgetSelection() async {
    if (!mounted) return;
    final historyBloc = context.read<ExpenseHistoryBloc>();
    final state = historyBloc.state;

    // Ensure budgets are loaded
    if (state.allBudgets.isEmpty) {
      historyBloc.add(const ExpenseHistoryToggleViewMode());
      // Wait for the bloc to load budgets
      await historyBloc.stream.firstWhere((s) => s.allBudgets.isNotEmpty);
    }

    if (!mounted) return;
    final current = historyBloc.state;
    final selected = await BudgetSelectionSheet.show(
      context: context,
      allBudgets: current.allBudgets,
      initiallySelected: current.selectedBudgetIds,
    );

    if (selected != null && mounted) {
      // Update selections then apply
      for (final id in current.allBudgets.map((b) => b.id)) {
        final wasSelected = current.selectedBudgetIds.contains(id);
        final nowSelected = selected.contains(id);
        if (wasSelected != nowSelected) {
          historyBloc.add(ExpenseHistoryToggleBudgetSelection(id));
        }
      }
      // Small delay for state to settle, then apply
      await Future<void>.delayed(Duration.zero);
      historyBloc.add(const ExpenseHistoryApplyCombinedView());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: BlocConsumer<ExpenseHistoryBloc, ExpenseHistoryState>(
                listener: (context, state) {
                  if (state.status == ExpenseHistoryStatus.error &&
                      state.allExpenses.isEmpty &&
                      !state.isCombinedMode) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            state.errorMessage ?? 'Unable to load expenses',
                          ),
                          backgroundColor: context.appColors.error,
                        ),
                      );
                  }
                },
                builder: (context, state) {
                  if (state.status == ExpenseHistoryStatus.loading &&
                      state.allExpenses.isEmpty) {
                    return const ExpenseListSkeleton();
                  }

                  if (state.status == ExpenseHistoryStatus.error &&
                      state.allExpenses.isEmpty) {
                    return ExpenseHistoryErrorWidget(
                      message: state.errorMessage ?? 'Unable to load expenses',
                      onRetry: () => context.read<ExpenseHistoryBloc>().add(
                        const ExpenseHistoryRefresh(),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      ExpenseSearchBar(
                        controller: _searchController,
                        onChanged: (query) => context
                            .read<ExpenseHistoryBloc>()
                            .add(ExpenseHistorySearchChanged(query)),
                        onClear: () => context.read<ExpenseHistoryBloc>().add(
                          const ExpenseHistorySearchChanged(''),
                        ),
                      ),
                      QuickFilterChips(
                        current: state.filter,
                        onSelected: (filter) => context
                            .read<ExpenseHistoryBloc>()
                            .add(ExpenseHistoryFilterChanged(filter)),
                      ),
                      ActiveFilterChips(
                        filter: state.filter,
                        categories: state.categories,
                        onChanged: (filter) => context
                            .read<ExpenseHistoryBloc>()
                            .add(ExpenseHistoryFilterChanged(filter)),
                      ),
                      if (state.isCombinedMode) _buildCombinedSummary(state),
                      SummaryCard(summary: state.summary),
                      Expanded(child: _buildResults(context, state)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/app/expenses/add'),
        backgroundColor: context.appColors.primary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Expense'),
        tooltip: 'Add a new expense',
      ),
    );
  }

  Widget _buildHeader() {
    return BlocBuilder<ExpenseHistoryBloc, ExpenseHistoryState>(
      buildWhen: (prev, curr) =>
          prev.viewMode != curr.viewMode ||
          prev.selectedBudgetIds != curr.selectedBudgetIds ||
          prev.budgetName != curr.budgetName,
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: state.isCombinedMode
                    ? _buildCombinedHeader(context, state)
                    : AppHeader(
                        title: 'Expenses',
                        subtitle:
                            state.budgetName ?? 'Track & manage your spending',
                      ),
              ),
              // View mode toggle
              IconButton(
                key: const Key('viewModeToggle'),
                icon: Icon(
                  state.isCombinedMode
                      ? Icons.account_balance_wallet_rounded
                      : Icons.dashboard_customize_rounded,
                  size: 22,
                ),
                tooltip: state.isCombinedMode
                    ? 'Switch to single budget'
                    : 'Combine budgets',
                onPressed: () {
                  if (state.isCombinedMode) {
                    _searchController.clear();
                    context.read<ExpenseHistoryBloc>().add(
                      const ExpenseHistoryExitCombinedView(),
                    );
                  } else {
                    context.read<ExpenseHistoryBloc>().add(
                      const ExpenseHistoryToggleViewMode(),
                    );
                    _openBudgetSelection();
                  }
                },
              ),
              IconButton(
                key: const Key('filterButton'),
                icon: const Icon(Icons.filter_list_rounded),
                tooltip: 'Filter expenses',
                onPressed: () =>
                    _openFilterSheet(context.read<ExpenseHistoryBloc>().state),
              ),
              IconButton(
                key: const Key('sortButton'),
                icon: const Icon(Icons.sort_rounded),
                tooltip: 'Sort expenses',
                onPressed: () =>
                    _openSortSheet(context.read<ExpenseHistoryBloc>().state),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCombinedHeader(BuildContext context, ExpenseHistoryState state) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Combined Expenses',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        GestureDetector(
          onTap: _openBudgetSelection,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  state.selectedBudgetsLabel.isEmpty
                      ? 'Select budgets'
                      : state.selectedBudgetsLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.appColors.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.edit_rounded,
                size: 12,
                color: context.appColors.secondary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
        Text(
          '${state.selectedBudgetIds.length} budgets',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildCombinedSummary(ExpenseHistoryState state) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.appColors.secondary.withValues(alpha: 0.06),
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(color: context.appColors.secondary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_rounded,
            size: 18,
            color: context.appColors.secondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Total spent',
            style: TextStyle(
              color: context.appColors.secondary.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            '\u20b9${state.combinedTotalAmount.toStringAsFixed(0)}',
            style: TextStyle(
              color: context.appColors.secondary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context, ExpenseHistoryState state) {
    if (state.isEmpty) {
      return ExpenseHistoryEmptyState(
        hasAnyExpenses: state.allExpenses.isNotEmpty,
        hasSearchQuery: state.query.isNotEmpty,
        hasActiveFilters: state.filter.isActive,
        onAddFirst: () => context.push('/app/expenses/add'),
        onClearFilters: () => context.read<ExpenseHistoryBloc>().add(
          const ExpenseHistoryClearFilters(),
        ),
      );
    }

    final groups = _groupExpensesUseCase(
      state.loadedExpenses,
      sort: state.sort,
    );

    return RefreshIndicator(
      onRefresh: () async {
        context.read<ExpenseHistoryBloc>().add(const ExpenseHistoryRefresh());
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: AppSpacing.xxl,
        ),
        itemCount: groups.length + 1,
        itemBuilder: (context, index) {
          if (index == groups.length) {
            return LoadingMoreIndicator(
              hasMore: state.hasMore,
              isLoading: state.status == ExpenseHistoryStatus.loadingMore,
            );
          }

          final group = groups[index];
          return _buildGroup(context, group, state);
        },
      ),
    );
  }

  Widget _buildGroup(
    BuildContext context,
    ExpenseGroup group,
    ExpenseHistoryState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExpenseGroupHeader(group: group),
        ...group.expenses.map((expense) {
          final category = _findCategory(state.categories, expense.categoryId);
          final budgetName = state.isCombinedMode
              ? state.budgetMap[expense.budgetId]?.name
              : null;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Dismissible(
              key: Key('dismiss_${expense.id}'),
              direction: DismissDirection.horizontal,
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.endToStart) {
                  return _confirmDelete(expense);
                }
                return false;
              },
              onDismissed: (direction) {},
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: context.appColors.secondary,
                  borderRadius: AppSpacing.borderRadiusLg,
                ),
                child: const Icon(Icons.edit_rounded, color: Colors.white),
              ),
              secondaryBackground: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: context.appColors.error,
                  borderRadius: AppSpacing.borderRadiusLg,
                ),
                child: const Icon(Icons.delete_rounded, color: Colors.white),
              ),
              child: ExpenseHistoryItem(
                expense: expense,
                category: category,
                budgetName: budgetName,
                onInfoTap: state.isCombinedMode
                    ? () => BudgetInfoBottomSheet.show(
                        context: context,
                        expense: expense,
                        budget: state.budgetMap[expense.budgetId],
                        categoryName: category?.name,
                      )
                    : null,
                onTap: () => context.push('/app/expenses/${expense.id}'),
              ),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
