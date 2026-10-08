import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/feedback/app_haptics.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../budget/domain/usecases/manage_budget_usecase.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_entity.dart';
import '../bloc/expense_bloc.dart';
import '../bloc/expense_event.dart';
import '../bloc/expense_state.dart';
import '../widgets/category_visuals.dart';
import '../widgets/expense_undo.dart';
import '../widgets/move_expense_sheet.dart';
import '../../../../core/navigation/push_unique.dart';

/// One expense on one surface: what it was and the amount, then its facts
/// (budget, date, time, category, note, tags) and the receipt. Below it,
/// duplicate, move and delete.
///
/// Delete asks nothing: the screen closes and "Undo" is offered for a few
/// seconds, the same as swiping a row away in the list.
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

  /// Name of the budget a move is heading to, for its confirmation.
  String? _movingTo;

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

  void _delete(ExpenseEntity expense) {
    AppHaptics.threshold();
    setState(() => _deleting = true);
    context.read<ExpenseBloc>().add(ExpenseDelete(expense.id));
  }

  Future<void> _moveToAnotherBudget(ExpenseEntity expense) async {
    final selected = await MoveExpenseSheet.show(
      context,
      expense: expense,
      budgets: _budgets,
    );
    if (selected == null || !mounted) return;
    _movingTo = selected.name;
    context.read<ExpenseBloc>().add(
      ExpenseUpdate(
        expense.copyWith(budgetId: selected.id, updatedAt: DateTime.now()),
      ),
    );
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/app/expenses');
    }
  }

  void _onState(BuildContext context, ExpenseState state) {
    final messenger = ScaffoldMessenger.of(context);
    if (state.status == ExpenseBlocStatus.success) {
      context.read<ExpenseBloc>().add(const ExpenseClearMessage());
      if (state.lastAction == ExpenseAction.deleted) {
        final deleted = state.lastDeleted;
        _leave();
        if (deleted != null) {
          ExpenseUndo.offer(messenger, deleted);
        } else {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Expense deleted')));
        }
        return;
      }
      if (state.lastAction == ExpenseAction.updated && _movingTo != null) {
        final name = _movingTo;
        _movingTo = null;
        AppHaptics.confirm();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Moved to $name')));
      }
    } else if (state.status == ExpenseBlocStatus.error) {
      setState(() {
        _deleting = false;
        _movingTo = null;
      });
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(state.message ?? 'Something went wrong')),
        );
      context.read<ExpenseBloc>().add(const ExpenseClearMessage());
    }
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
                onPressed: () async {
                  final bloc = context.read<ExpenseBloc>();
                  await context.pushUnique('/app/expenses/edit/${expense.id}');
                  // The edit screen has its own bloc; show the saved values.
                  if (context.mounted) bloc.add(ExpenseLoadById(expense.id));
                },
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<ExpenseBloc, ExpenseState>(
        listener: _onState,
        builder: (context, state) {
          final Widget child;
          final expense = state.expense;
          if (state.status == ExpenseBlocStatus.loading && expense == null) {
            child = const FormSkeleton(key: ValueKey('loading'), rows: 4);
          } else if (expense == null) {
            child = EmptyState(
              key: const ValueKey('missing'),
              icon: Icons.receipt_long_outlined,
              title: 'Expense not found',
              message: 'It may have been deleted on another screen.',
              actionLabel: 'Back to expenses',
              actionIcon: Icons.arrow_back_rounded,
              onAction: _leave,
            );
          } else {
            child = _Details(
              key: const ValueKey('details'),
              expense: expense,
              category: _categoryFor(state.categories, expense.categoryId),
              budget: _budgetFor(expense),
              canMove: _budgets.any(
                (b) => b.id != expense.budgetId && !b.isArchived,
              ),
              busy: state.isBusy || _deleting,
              onDuplicate: () =>
                  context.pushUnique('/app/expenses/add?copy=${expense.id}'),
              onMove: () => _moveToAnotherBudget(expense),
              onDelete: () => _delete(expense),
            );
          }
          return AppStateSwitcher(child: child);
        },
      ),
    );
  }
}

/// Notes up to this long show whole as the title.
const int _titleNoteLength = 80;

class _Details extends StatelessWidget {
  final ExpenseEntity expense;
  final ExpenseCategory? category;
  final BudgetEntity? budget;
  final bool canMove;
  final bool busy;
  final VoidCallback onDuplicate;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  const _Details({
    super.key,
    required this.expense,
    required this.category,
    required this.budget,
    required this.canMove,
    required this.busy,
    required this.onDuplicate,
    required this.onMove,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = category != null
        ? CategoryVisuals.adaptiveColor(context, category!.colorHex)
        : theme.colorScheme.onSurfaceVariant;
    final icon = category != null
        ? CategoryVisuals.iconFor(category!.icon)
        : Icons.category_rounded;
    final categoryName = category?.name ?? 'Uncategorised';
    final note = expense.note?.trim();
    final hasNote = note != null && note.isNotEmpty;
    final receiptPath = expense.receiptImagePath;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final critical = context.tone(AppTone.critical).accent;

    return ListView(
      padding: AppSpacing.pagePadding,
      children: [
        AppSurface(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.mlg,
            AppSpacing.mlg,
            AppSpacing.mlg,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconTile(icon: icon, color: color),
                  const SizedBox(width: AppSpacing.smd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasNote ? note : categoryName,
                          style: theme.textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // The category sits under a note; without one the title is
                        // the category. The date is a fact below.
                        if (hasNote) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(categoryName, style: muted),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppMoney(
                amount: expense.amount,
                currency: budget?.currency,
                role: MoneyRole.display,
              ),
              const SizedBox(height: AppSpacing.md),
              Divider(color: theme.colorScheme.outlineVariant),
              _Fact(label: 'Budget', value: budget?.name ?? 'Unknown budget'),
              _Fact(
                label: 'Date',
                value: DateFormat('EEE, d MMM yyyy').format(expense.date),
              ),
              _Fact(label: 'Time', value: DateFormat.jm().format(expense.time)),
              // A short note is already the title; only a long one, which
              // the title may cut short, is repeated here in full.
              if (hasNote && note.length > _titleNoteLength)
                _Fact(label: 'Note', value: note),
              if (expense.tags.isNotEmpty)
                _Fact(
                  label: 'Tags',
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final tag in expense.tags)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: AppSpacing.borderRadiusXs,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xxs,
                            ),
                            child: Text(
                              '#$tag',
                              style: theme.textTheme.labelMedium,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (receiptPath != null) ...[
                Divider(color: theme.colorScheme.outlineVariant),
                const SizedBox(height: AppSpacing.sm),
                Text('Receipt', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                if (File(receiptPath).existsSync())
                  ClipRRect(
                    borderRadius: AppSpacing.borderRadiusMd,
                    child: Image.file(
                      File(receiptPath),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, _, _) =>
                          const Text('Receipt unavailable'),
                    ),
                  )
                else
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: AppSizes.iconSm,
                        color: critical,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Receipt file is missing',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: critical,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Actions sit on the page, quietest first.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            TextButton.icon(
              key: const Key('duplicateExpenseButton'),
              onPressed: busy ? null : onDuplicate,
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Duplicate'),
            ),
            if (canMove)
              TextButton.icon(
                key: const Key('moveExpenseBudgetButton'),
                onPressed: busy ? null : onMove,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Move to another budget'),
              ),
            TextButton.icon(
              key: const Key('deleteExpenseButton'),
              onPressed: busy ? null : onDelete,
              style: TextButton.styleFrom(foregroundColor: critical),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete expense'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Added ${DateFormat('d MMM yyyy, h:mm a').format(expense.createdAt)}'
          '${expense.updatedAt.difference(expense.createdAt).inMinutes > 0 ? ' · Edited ${DateFormat('d MMM yyyy, h:mm a').format(expense.updatedAt)}' : ''}',
          style: muted,
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// One fact: the label on the left, the value beside it; stacked when the
/// text is too large to share a line.
class _Fact extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? child;

  const _Fact({required this.label, this.value, this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelText = Text(
      label,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    final valueWidget =
        child ?? Text(value ?? '', style: theme.textTheme.bodyLarge);
    final stacked = MediaQuery.textScalerOf(context).scale(14) > 20;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  labelText,
                  const SizedBox(height: AppSpacing.xxs),
                  valueWidget,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 96, child: labelText),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: valueWidget),
                ],
              ),
      ),
    );
  }
}
