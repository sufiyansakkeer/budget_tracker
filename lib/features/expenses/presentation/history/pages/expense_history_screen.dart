import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_spacing.dart';
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

/// Material 3 expense history screen with search, filters, sorting, grouping,
/// pagination, swipe actions, and pull-to-refresh.
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(
          'This will permanently remove the expense of ₹${expense.amount}. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('confirmHistoryDelete'),
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.dangerRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      // Trigger the existing delete flow via the CRUD ExpenseBloc.
      // The ExpenseRefreshBus automatically refreshes history, dashboard, and
      // budget engine.
      expenseBloc.add(ExpenseDelete(expense.id));
    }
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense History'),
        actions: [
          IconButton(
            key: const Key('sortButton'),
            icon: const Icon(Icons.sort),
            tooltip: 'Sort expenses',
            onPressed: () =>
                _openSortSheet(context.read<ExpenseHistoryBloc>().state),
          ),
          IconButton(
            key: const Key('filterButton'),
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter expenses',
            onPressed: () =>
                _openFilterSheet(context.read<ExpenseHistoryBloc>().state),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/expenses/add'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
        tooltip: 'Add a new expense',
      ),
      body: BlocBuilder<ExpenseHistoryBloc, ExpenseHistoryState>(
        builder: (context, state) {
          if (state.status == ExpenseHistoryStatus.loading &&
              state.allExpenses.isEmpty) {
            return const Center(child: CircularProgressIndicator());
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
                onChanged: (query) => context.read<ExpenseHistoryBloc>().add(
                  ExpenseHistorySearchChanged(query),
                ),
                onClear: () => context.read<ExpenseHistoryBloc>().add(
                  const ExpenseHistorySearchChanged(''),
                ),
              ),
              QuickFilterChips(
                current: state.filter,
                onSelected: (filter) => context.read<ExpenseHistoryBloc>().add(
                  ExpenseHistoryFilterChanged(filter),
                ),
              ),
              ActiveFilterChips(
                filter: state.filter,
                categories: state.categories,
                onChanged: (filter) => context.read<ExpenseHistoryBloc>().add(
                  ExpenseHistoryFilterChanged(filter),
                ),
              ),
              SummaryCard(summary: state.summary),
              Expanded(child: _buildResults(context, state)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResults(BuildContext context, ExpenseHistoryState state) {
    if (state.isEmpty) {
      return ExpenseHistoryEmptyState(
        hasAnyExpenses: state.allExpenses.isNotEmpty,
        hasSearchQuery: state.query.isNotEmpty,
        hasActiveFilters: state.filter.isActive,
        onAddFirst: () => context.push('/expenses/add'),
        onClearFilters: () => context.read<ExpenseHistoryBloc>().add(
          const ExpenseHistoryClearFilters(),
        ),
      );
    }

    final groups = _groupExpensesUseCase(state.loadedExpenses);

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
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Dismissible(
              key: Key('dismiss_${expense.id}'),
              direction: DismissDirection.horizontal,
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.endToStart) {
                  // Left swipe => delete
                  return _confirmDelete(expense);
                }
                // Right swipe => edit
                return false;
              },
              onDismissed: (direction) {},
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppSpacing.borderRadiusLg,
                ),
                child: const Icon(Icons.edit, color: Colors.white),
              ),
              secondaryBackground: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.dangerRed,
                  borderRadius: AppSpacing.borderRadiusLg,
                ),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              child: ExpenseHistoryItem(
                expense: expense,
                category: category,
                onTap: () => context.push('/expenses/${expense.id}'),
              ),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
