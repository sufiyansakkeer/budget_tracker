import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../budget/presentation/widgets/active_budget_selector.dart';
import '../../domain/entities/expense_category.dart';
import '../bloc/expense_bloc.dart';
import '../bloc/expense_event.dart';
import '../bloc/expense_state.dart';
import '../widgets/expense_summary_card.dart';
import '../../../../core/theme/app_colors_extension.dart';

/// Lists all expenses with category info and navigation to details.
class ExpensesListScreen extends StatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  State<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ExpenseBloc>().add(const ExpenseLoadAll());
    if (context.read<ExpenseBloc>().state.categories.isEmpty) {
      context.read<ExpenseBloc>().add(const ExpenseLoadCategories());
    }
  }

  ExpenseCategory? _findCategory(List<ExpenseCategory> categories, String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Expenses'),
        actions: [
          IconButton(
            key: const Key('historyEntryButton'),
            icon: const Icon(Icons.history),
            tooltip: 'Expense History',
            onPressed: () => context.push('/app/expenses'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/app/expenses/add'),
        backgroundColor: context.appColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
        tooltip: 'Add a new expense',
      ),
      body: BlocConsumer<ExpenseBloc, ExpenseState>(
        listener: (context, state) {
          if (state.status == ExpenseBlocStatus.error) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.message ?? 'Something went wrong'),
                  backgroundColor: context.appColors.error,
                ),
              );
            context.read<ExpenseBloc>().add(const ExpenseClearMessage());
          }
        },
        builder: (context, state) {
          if (state.status == ExpenseBlocStatus.loading &&
              state.expenses.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.expenses.isEmpty) {
            return _buildEmpty(context);
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<ExpenseBloc>().add(const ExpenseLoadAll());
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: ActiveBudgetSelector(),
                ),
                ...state.expenses.map((expense) {
                  final category = _findCategory(
                    state.categories,
                    expense.categoryId,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ExpenseSummaryCard(
                      expense: expense,
                      category: category,
                      onTap: () => context.push('/app/expenses/${expense.id}'),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('No expenses yet', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tap "Add Expense" to get started',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
