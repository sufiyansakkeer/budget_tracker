import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../budget/domain/usecases/manage_budget_usecase.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_entity.dart';
import '../bloc/expense_bloc.dart';
import '../bloc/expense_event.dart';
import '../bloc/expense_state.dart';
import '../widgets/category_visuals.dart';
import '../widgets/delete_expense_dialog.dart';
import '../widgets/move_expense_sheet.dart';

/// Detail page for a single expense.
class ExpenseDetailsScreen extends StatefulWidget {
  final String expenseId;

  const ExpenseDetailsScreen({super.key, required this.expenseId});

  @override
  State<ExpenseDetailsScreen> createState() => _ExpenseDetailsScreenState();
}

class _ExpenseDetailsScreenState extends State<ExpenseDetailsScreen> {
  late final ManageBudgetUseCase _manageBudget = getIt<ManageBudgetUseCase>();
  List<BudgetEntity> _budgets = const [];
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<ExpenseBloc>();
    bloc.add(ExpenseLoadById(widget.expenseId));
    if (bloc.state.categories.isEmpty) {
      bloc.add(const ExpenseLoadCategories());
    }
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    try {
      final budgets = await _manageBudget.getAll();
      if (!mounted) return;
      setState(() => _budgets = budgets);
    } catch (_) {
      // Budgets are supplementary here; the expense still renders.
    }
  }

  BudgetEntity? _budgetFor(ExpenseEntity expense) {
    for (final budget in _budgets) {
      if (budget.id == expense.budgetId) return budget;
    }
    return null;
  }

  ExpenseCategory? _categoryFor(List<ExpenseCategory> categories, String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  Future<void> _confirmDelete(ExpenseEntity expense, String? currency) async {
    final confirmed = await showDeleteExpenseDialog(
      context,
      amount: expense.amount,
      currency: currency ?? '',
    );
    if (confirmed && mounted) {
      setState(() => _deleting = true);
      context.read<ExpenseBloc>().add(ExpenseDelete(expense.id));
    }
  }

  Future<void> _moveToAnotherBudget(ExpenseEntity expense) async {
    final selected = await MoveExpenseSheet.show(
      context,
      expense: expense,
      budgets: _budgets,
    );
    if (selected == null || !mounted) return;
    context.read<ExpenseBloc>().add(
      ExpenseUpdate(
        expense.copyWith(budgetId: selected.id, updatedAt: DateTime.now()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense'),
        actions: [
          BlocBuilder<ExpenseBloc, ExpenseState>(
            builder: (context, state) {
              final expense = state.expense;
              if (expense == null) return const SizedBox.shrink();
              return IconButton(
                key: const Key('editExpenseButton'),
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit expense',
                onPressed: () =>
                    context.push('/app/expenses/edit/${expense.id}'),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<ExpenseBloc, ExpenseState>(
        listener: (context, state) {
          if (state.status == ExpenseBlocStatus.success) {
            final wasDelete = _deleting;
            context.read<ExpenseBloc>().add(const ExpenseClearMessage());
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    state.message ?? (wasDelete ? 'Expense deleted' : 'Saved'),
                  ),
                ),
              );
            if (wasDelete && context.canPop()) context.pop();
          } else if (state.status == ExpenseBlocStatus.error) {
            setState(() => _deleting = false);
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.message ?? 'Something went wrong'),
                ),
              );
            context.read<ExpenseBloc>().add(const ExpenseClearMessage());
          }
        },
        builder: (context, state) {
          final Widget child;
          if (state.status == ExpenseBlocStatus.loading &&
              state.expense == null) {
            child = const FormSkeleton(key: ValueKey('loading'), rows: 4);
          } else if (state.expense == null) {
            child = EmptyState(
              key: const ValueKey('missing'),
              icon: Icons.receipt_long_outlined,
              title: 'Expense not found',
              message: 'It may have been deleted on another screen.',
              actionLabel: 'Back to expenses',
              actionIcon: Icons.arrow_back_rounded,
              onAction: () => context.canPop()
                  ? context.pop()
                  : context.go('/app/expenses'),
            );
          } else {
            child = _Details(
              key: const ValueKey('details'),
              expense: state.expense!,
              category: _categoryFor(
                state.categories,
                state.expense!.categoryId,
              ),
              budget: _budgetFor(state.expense!),
              canMove: _budgets.any(
                (b) => b.id != state.expense!.budgetId && !b.isArchived,
              ),
              busy: state.isBusy,
              onMove: () => _moveToAnotherBudget(state.expense!),
              onDelete: () => _confirmDelete(
                state.expense!,
                _budgetFor(state.expense!)?.currency,
              ),
            );
          }
          return AppStateSwitcher(child: child);
        },
      ),
    );
  }
}

class _Details extends StatelessWidget {
  final ExpenseEntity expense;
  final ExpenseCategory? category;
  final BudgetEntity? budget;
  final bool canMove;
  final bool busy;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  const _Details({
    super.key,
    required this.expense,
    required this.category,
    required this.budget,
    required this.canMove,
    required this.busy,
    required this.onMove,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final color = category != null
        ? CategoryVisuals.adaptiveColor(context, category!.colorHex)
        : theme.colorScheme.onSurfaceVariant;
    final icon = category != null
        ? CategoryVisuals.iconFor(category!.icon)
        : Icons.category_rounded;
    final categoryName = category?.name ?? 'Uncategorised';
    final hasNote = expense.note != null && expense.note!.trim().isNotEmpty;
    final receiptPath = expense.receiptImagePath;

    return ListView(
      padding: AppSpacing.pagePadding,
      children: [
        // Hero: amount + category
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.mlg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconTile(icon: icon, color: color, size: AppSizes.avatarLg),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasNote ? expense.note!.trim() : categoryName,
                          style: theme.textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          hasNote
                              ? categoryName
                              : DateFormat('EEEE, d MMM').format(expense.date),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  CurrencyFormatter.format(
                    expense.amount,
                    code: budget?.currency,
                  ),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Facts
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            children: [
              _FactRow(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Budget',
                value: budget?.name ?? 'Unknown budget',
                valueColor: theme.colorScheme.primary,
              ),
              _FactRow(
                icon: Icons.calendar_today_outlined,
                label: 'Date',
                value: DateFormat('EEE, d MMM yyyy').format(expense.date),
              ),
              _FactRow(
                icon: Icons.access_time_rounded,
                label: 'Time',
                value: DateFormat('h:mm a').format(expense.time),
              ),
              _FactRow(
                icon: Icons.category_outlined,
                label: 'Category',
                value: categoryName,
              ),
              if (hasNote)
                _FactRow(
                  icon: Icons.notes_rounded,
                  label: 'Note',
                  value: expense.note!.trim(),
                ),
              if (expense.tags.isNotEmpty)
                _FactRow(
                  icon: Icons.sell_outlined,
                  label: 'Tags',
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final tag in expense.tags)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: colors.tertiary.withValues(alpha: 0.12),
                            borderRadius: AppSpacing.borderRadiusXs,
                          ),
                          child: Text(
                            '#$tag',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.tertiary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Receipt
        if (receiptPath != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Receipt', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                if (File(receiptPath).existsSync())
                  ClipRRect(
                    borderRadius: AppSpacing.borderRadiusMd,
                    child: Image.file(
                      File(receiptPath),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) =>
                          const Text('Receipt unavailable'),
                    ),
                  )
                else
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: AppSizes.iconSm,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Receipt file is missing',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.lg),

        // Actions
        if (canMove) ...[
          OutlinedButton.icon(
            key: const Key('moveExpenseBudgetButton'),
            onPressed: busy ? null : onMove,
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Move to another budget'),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        OutlinedButton.icon(
          key: const Key('deleteExpenseButton'),
          onPressed: busy ? null : onDelete,
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.error,
            side: BorderSide(color: colors.error.withValues(alpha: 0.6)),
          ),
          icon: busy
              ? const SizedBox(
                  width: AppSizes.iconSm,
                  height: AppSizes.iconSm,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline_rounded),
          label: const Text('Delete expense'),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Metadata
        Text(
          'Added ${DateFormat('d MMM yyyy, h:mm a').format(expense.createdAt)}'
          '${expense.updatedAt.difference(expense.createdAt).inMinutes > 0 ? ' · Edited ${DateFormat('d MMM yyyy, h:mm a').format(expense.updatedAt)}' : ''}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? child;
  final Color? valueColor;

  const _FactRow({
    required this.icon,
    required this.label,
    this.value,
    this.child,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: AppSizes.iconMd,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                child ??
                    Text(
                      value ?? '',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: valueColor,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
