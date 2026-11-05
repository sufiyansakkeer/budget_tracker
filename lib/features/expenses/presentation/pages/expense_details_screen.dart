import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/feedback/app_haptics.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_page_body.dart';
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../../core/router/app_router.dart';
import '../../../budget/domain/usecases/manage_budget_usecase.dart';
import '../../../pay_later/domain/entities/pay_later_tab.dart';
import '../../../pay_later/domain/entities/purchase_change_impact.dart';
import '../../../pay_later/presentation/widgets/purchase_impact_dialog.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_entity.dart';
import '../bloc/expense_bloc.dart';
import '../bloc/expense_event.dart';
import '../bloc/expense_state.dart';
import '../widgets/category_visuals.dart';
import '../widgets/expense_undo.dart';
import '../widgets/move_expense_sheet.dart';
import '../widgets/paid_bill.dart';
import '../widgets/receipt_photo.dart';
import '../../../../core/navigation/push_unique.dart';

/// One expense on one surface: what it was and the amount, then its facts
/// (budget, date, time, category, note, tags) and the receipt. Below it,
/// duplicate, move and delete.
///
/// Delete asks nothing: the screen closes and "Undo" is offered for a few
/// seconds, the same as swiping a row away in the list. A purchase on a Pay
/// later tab with payment money on it is the exception: the delete says
/// where that money goes and asks first, with no Undo after.
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

  /// The expense couldn't be read (as opposed to no longer existing).
  bool _openFailed = false;

  /// The budget a move is heading to and the expense as it was, for
  /// "Moved to … · Undo".
  ({String name, ExpenseEntity original})? _moving;

  /// The bill the expense paid ([ExpenseEntity.billId]) and its title once
  /// read, for "Paid bill".
  String? _billId;
  String? _billTitle;

  /// The Pay later tab the expense is on and how much is paid on it; null
  /// when on no tab (or not known).
  ({PayLaterTab tab, double paid})? _tabInfo;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<ExpenseBloc>();
    bloc.add(ExpenseLoadById(widget.expenseId));
    if (bloc.state.categories.isEmpty) {
      bloc.add(const ExpenseLoadCategories());
    }
    _loadBudgets();
    _loadTabInfo();
  }

  Future<void> _loadTabInfo() async {
    try {
      final info = await context.read<ExpenseBloc>().tabPurchases.tabInfoFor(
        widget.expenseId,
      );
      if (!mounted) return;
      setState(() => _tabInfo = info);
    } catch (e) {
      // Supplementary, like the budgets: the expense still renders.
      debugPrint('[error] Loading the Pay later tab of an expense: $e');
    }
  }

  Future<void> _loadBudgets() async {
    try {
      final budgets = await _manageBudget.getAll();
      if (!mounted) return;
      setState(() => _budgets = budgets);
    } catch (e) {
      // Budgets are supplementary here; the expense still renders.
      debugPrint('[error] Loading budgets for an expense: $e');
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

  /// Deletes at once with Undo, unless the expense is a tab purchase with
  /// payment money on it: then it says where that money goes, asks, and
  /// offers no Undo. A failed check deletes nothing.
  Future<void> _delete(ExpenseEntity expense) async {
    // Busy at once, so a second tap while payments are checked does nothing.
    setState(() => _deleting = true);
    final bloc = context.read<ExpenseBloc>();
    final PurchaseChangeImpact? impact;
    try {
      impact = await bloc.tabPurchases.impactOf(expense.id, deleting: true);
    } catch (e) {
      debugPrint('[error] Checking payments before deleting an expense: $e');
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(PurchaseImpactDialog.deleteCheckFailed)),
        );
      return;
    }
    if (!mounted) return;
    var undoable = true;
    if (impact != null && impact.touchesPayments) {
      final confirmed = await PurchaseImpactDialog.show(
        context,
        impact: impact,
        deleting: true,
      );
      if (!mounted) return;
      if (!confirmed) {
        setState(() => _deleting = false);
        return;
      }
      undoable = false;
    }
    AppHaptics.threshold();
    bloc.add(ExpenseDelete(expense.id, undoable: undoable));
  }

  /// Reads the title of the bill [expense] paid, once per bill.
  void _loadBillTitle(ExpenseEntity? expense) {
    final id = expense?.billId;
    if (id == _billId) return;
    _billId = id;
    _billTitle = null;
    if (expense == null || id == null) return;
    PaidBill.titleOf(expense).then((title) {
      if (mounted && _billId == id) setState(() => _billTitle = title);
    });
  }

  Future<void> _moveToAnotherBudget(ExpenseEntity expense) async {
    final selected = await MoveExpenseSheet.show(
      context,
      expense: expense,
      budgets: _budgets,
      billTitle: _billTitle,
    );
    if (selected == null || !mounted) return;
    _moving = (name: selected.name, original: expense);
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
    _loadBillTitle(state.expense);
    final messenger = ScaffoldMessenger.of(context);
    if (state.status == ExpenseBlocStatus.success) {
      context.read<ExpenseBloc>().add(const ExpenseClearMessage());
      if (state.lastAction == ExpenseAction.deleted) {
        final deleted = state.lastDeleted;
        final link = state.lastDeletedLink;
        _leave();
        if (deleted != null) {
          ExpenseUndo.offer(messenger, deleted, link: link);
        } else {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Expense deleted')));
        }
        return;
      }
      if (state.lastAction == ExpenseAction.updated && _moving != null) {
        final (:name, :original) = _moving!;
        _moving = null;
        AppHaptics.confirm();
        final bloc = context.read<ExpenseBloc>();
        // The stored row: a move unlinks a bill payment from its bill.
        bloc.add(ExpenseLoadById(original.id));
        ExpenseUndo.offerMoved(
          messenger,
          original,
          to: name,
          onUndone: () {
            if (mounted) bloc.add(ExpenseLoadById(original.id));
          },
        );
      }
    } else if (state.status == ExpenseBlocStatus.error) {
      // A failed read shows the error view with a retry, not "not found"
      // and a toast.
      final openFailed =
          state.expense == null &&
          state.message == ExpenseBloc.openFailedMessage;
      setState(() {
        _deleting = false;
        _moving = null;
        _openFailed = openFailed;
      });
      if (!openFailed) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                state.message ?? "Couldn't finish that. Try again.",
              ),
            ),
          );
      }
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
                  if (context.mounted) {
                    bloc.add(ExpenseLoadById(expense.id));
                    _loadTabInfo();
                  }
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
          } else if (expense == null && _openFailed) {
            child = ErrorState(
              key: const ValueKey('error'),
              title: "Couldn't open this expense",
              message: "It's still on this device. Try again in a moment.",
              onRetry: () {
                setState(() => _openFailed = false);
                context.read<ExpenseBloc>().add(
                  ExpenseLoadById(widget.expenseId),
                );
              },
            );
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
              billTitle: expense.billId == null ? null : _billTitle,
              tabInfo: _tabInfo,
              onOpenTab: (tabId) async {
                await context.pushUnique('${AppRouter.payLaterPath}/$tabId');
                // A payment made there changes "paid X of Y" here.
                if (mounted) _loadTabInfo();
              },
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

  /// The bill the expense paid; null when none (or not known).
  final String? billTitle;
  final ({PayLaterTab tab, double paid})? tabInfo;
  final ValueChanged<String> onOpenTab;
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
    required this.billTitle,
    required this.tabInfo,
    required this.onOpenTab,
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

    return AppPageBody(
      builder: (context, padding) => ListView(
        padding: padding,
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
                if (billTitle != null)
                  _Fact(label: 'Paid bill', value: billTitle),
                if (tabInfo case final info?)
                  _TabFact(
                    tab: info.tab,
                    paid: info.paid,
                    amount: expense.amount,
                    onTap: () => onOpenTab(info.tab.id),
                  ),
                _Fact(
                  label: 'Date',
                  value: DateFormat('EEE, d MMM yyyy').format(expense.date),
                ),
                _Fact(
                  label: 'Time',
                  value: DateFormat.jm().format(expense.time),
                ),
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
                  _Receipt(path: receiptPath),
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
      ),
    );
  }
}

/// The receipt, once its file is known to exist. Checked once per path off
/// the build: a sync check ran on every rebuild.
class _Receipt extends StatefulWidget {
  final String path;

  const _Receipt({required this.path});

  @override
  State<_Receipt> createState() => _ReceiptState();
}

class _ReceiptState extends State<_Receipt> {
  /// Null while checking.
  bool? _exists;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void didUpdateWidget(covariant _Receipt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _check();
  }

  Future<void> _check() async {
    final path = widget.path;
    bool exists;
    try {
      exists = await File(path).exists();
    } catch (_) {
      exists = false;
    }
    if (mounted && path == widget.path) setState(() => _exists = exists);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final critical = context.tone(AppTone.critical).accent;
    return switch (_exists) {
      null => const SizedBox.shrink(),
      true => ClipRRect(
        borderRadius: AppSpacing.borderRadiusMd,
        child: ReceiptPhoto(
          path: widget.path,
          errorBuilder: (_, _, _) => const Text('Receipt unavailable'),
        ),
      ),
      false => Row(
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
              style: theme.textTheme.bodyMedium?.copyWith(color: critical),
            ),
          ),
        ],
      ),
    };
  }
}

/// The Pay later fact: "On Campus cafeteria · paid 2.000 of 3.500",
/// opening the tab.
class _TabFact extends StatelessWidget {
  final PayLaterTab tab;
  final double paid;
  final double amount;
  final VoidCallback onTap;

  const _TabFact({
    required this.tab,
    required this.paid,
    required this.amount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paidText = CurrencyFormatter.format(paid, code: tab.currency);
    final total = CurrencyFormatter.format(amount, code: tab.currency);
    return InkWell(
      key: const Key('expenseTabRow'),
      onTap: onTap,
      borderRadius: AppSpacing.borderRadiusSm,
      child: _Fact(
        label: 'Pay later',
        child: Row(
          children: [
            Expanded(
              child: Text(
                'On ${tab.name} · paid $paidText of $total',
                style: theme.textTheme.bodyLarge,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: AppSizes.iconSm + 4,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
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
