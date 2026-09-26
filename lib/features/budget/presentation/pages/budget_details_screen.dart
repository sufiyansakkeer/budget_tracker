import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/widgets/animated_amount.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_progress.dart';
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/monthly_statistics_entity.dart';
import '../../domain/repository/budget_repository.dart';
import '../../domain/usecases/manage_budget_usecase.dart';
import '../widgets/budget_visuals.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_fab.dart';
import '../../../../core/events/refresh_bus.dart';
import '../../../../core/navigation/push_unique.dart';

/// Entry point for a selected budget: amount, progress, period, status and
/// actions (edit, set active, archive, duplicate, delete, add expense).
class BudgetDetailsScreen extends StatefulWidget {
  final String budgetId;

  const BudgetDetailsScreen({super.key, required this.budgetId});

  @override
  State<BudgetDetailsScreen> createState() => _BudgetDetailsScreenState();
}

class _BudgetDetailsScreenState extends State<BudgetDetailsScreen> {
  late final ManageBudgetUseCase _manageBudget = getIt<ManageBudgetUseCase>();
  late final BudgetRepository _budgetRepository = getIt<BudgetRepository>();

  BudgetEntity? _budget;
  MonthlyStatisticsEntity _stats = MonthlyStatisticsEntity.empty;
  bool _isActive = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  StreamSubscription<void>? _expenseSubscription;
  StreamSubscription<void>? _budgetSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    _expenseSubscription = RefreshBuses.expenses.changes.listen((_) {
      if (mounted) _load(silent: true);
    });
    _budgetSubscription = RefreshBuses.budgets.changes.listen((_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _expenseSubscription?.cancel();
    _budgetSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent || _budget == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final activeId = await _manageBudget.activeBudgetId();
      final budget = await _manageBudget.getById(widget.budgetId);
      final stats = budget == null
          ? MonthlyStatisticsEntity.empty
          : await _budgetRepository.getBudgetStatistics(
              budget.id,
              referenceDate: DateTime.now(),
            );
      if (!mounted) return;
      setState(() {
        _budget = budget;
        _stats = stats;
        _isActive = budget != null && budget.id == activeId;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Couldn't load this budget.";
      });
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) _notify("Something went wrong. Please try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setActive() => _run(() async {
    await _manageBudget.setActive(widget.budgetId);
    RefreshBuses.budgets.notifyChanged();
    if (!mounted) return;
    setState(() => _isActive = true);
    _notify('${_budget?.name ?? 'Budget'} is now your active budget');
  });

  Future<void> _archive() => _run(() async {
    await _manageBudget.archive(widget.budgetId, archived: true);
    RefreshBuses.budgets.notifyChanged();
    if (!mounted) return;
    setState(() => _budget = _budget?.copyWith(isArchived: true));
    _notify('Budget archived');
  });

  Future<void> _restore() => _run(() async {
    await _manageBudget.archive(widget.budgetId, archived: false);
    RefreshBuses.budgets.notifyChanged();
    if (!mounted) return;
    setState(() => _budget = _budget?.copyWith(isArchived: false));
    _notify('Budget restored');
  });

  Future<void> _duplicate() async {
    final name = await AppDialog.show<String>(
      context: context,
      builder: (context) =>
          _DuplicateBudgetDialog(initialName: '${_budget!.name} (Copy)'),
    );
    if (name == null || name.isEmpty || !mounted) return;
    await _run(() async {
      await _manageBudget.duplicate(widget.budgetId, newName: name);
      RefreshBuses.budgets.notifyChanged();
      if (mounted) _notify('Created "$name"');
    });
  }

  Future<void> _delete() async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Delete this budget?',
      message:
          'This permanently deletes "${_budget?.name}" and every expense '
          'recorded in it. This cannot be undone.',
      confirmLabel: 'Delete',
      icon: Icons.delete_forever_rounded,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    await _run(() async {
      // Stop reacting to the buses first: the delete notifies them, and a
      // reload of a budget that no longer exists would flash "Budget not
      // found" during the pop animation.
      _expenseSubscription?.cancel();
      _budgetSubscription?.cancel();
      await _manageBudget.delete(widget.budgetId);
      RefreshBuses.budgets.notifyChanged();
      if (!mounted) return;
      _notify('Budget deleted');
      context.pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final budget = _budget;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        actions: [
          if (budget != null) ...[
            IconButton(
              tooltip: 'Edit budget',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _busy
                  ? null
                  : () => context.pushUnique(
                      '/app/budgets/${widget.budgetId}/edit',
                    ),
            ),
            PopupMenuButton<String>(
              enabled: !_busy,
              tooltip: 'More actions',
              onSelected: (value) {
                switch (value) {
                  case 'setActive':
                    _setActive();
                  case 'archive':
                    _archive();
                  case 'restore':
                    _restore();
                  case 'duplicate':
                    _duplicate();
                  case 'delete':
                    _delete();
                }
              },
              itemBuilder: (context) => [
                if (!_isActive && !budget.isArchived)
                  const PopupMenuItem(
                    value: 'setActive',
                    child: ListTile(
                      leading: Icon(Icons.check_circle_outline_rounded),
                      title: Text('Set as active'),
                    ),
                  ),
                PopupMenuItem(
                  value: budget.isArchived ? 'restore' : 'archive',
                  child: ListTile(
                    leading: Icon(
                      budget.isArchived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                    ),
                    title: Text(budget.isArchived ? 'Restore' : 'Archive'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'duplicate',
                  child: ListTile(
                    leading: Icon(Icons.copy_rounded),
                    title: Text('Duplicate'),
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: context.appColors.error,
                    ),
                    title: Text(
                      'Delete',
                      style: TextStyle(color: context.appColors.error),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: SafeArea(bottom: false, child: AppStateSwitcher(child: _body())),
      floatingActionButton: budget != null && !budget.isArchived
          ? AppFab(
              heroTag: 'budget_details_fab',
              onPressed: _busy
                  ? null
                  : () => context.pushUnique('/app/expenses/add'),
              icon: Icons.add_rounded,
              label: 'Add expense',
            )
          : null,
    );
  }

  Widget _body() {
    if (_loading) return const FormSkeleton(key: ValueKey('loading'), rows: 4);
    if (_error != null) {
      return ErrorState(
        key: const ValueKey('error'),
        message: _error!,
        onRetry: _load,
      );
    }
    final budget = _budget;
    if (budget == null) {
      return EmptyState(
        key: const ValueKey('missing'),
        icon: Icons.search_off_rounded,
        title: 'Budget not found',
        message: 'It may have been deleted.',
        actionLabel: 'Back to budgets',
        actionIcon: Icons.arrow_back_rounded,
        onAction: () =>
            context.canPop() ? context.pop() : context.go('/app/budgets'),
      );
    }
    return _Content(
      key: const ValueKey('content'),
      budget: budget,
      stats: _stats,
      isActive: _isActive,
      busy: _busy,
      onSetActive: _setActive,
      onRestore: _restore,
    );
  }
}

class _Content extends StatelessWidget {
  final BudgetEntity budget;
  final MonthlyStatisticsEntity stats;
  final bool isActive;
  final bool busy;
  final VoidCallback onSetActive;
  final VoidCallback onRestore;

  const _Content({
    super.key,
    required this.budget,
    required this.stats,
    required this.isActive,
    required this.busy,
    required this.onSetActive,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final accent = BudgetVisuals.colorFor(context, budget);
    final now = DateTime.now();
    final phase = budget.phaseOn(now);
    final spent = stats.totalSpent;
    final remaining = budget.monthlyAmount - spent;
    final utilization = budget.monthlyAmount <= 0
        ? 0.0
        : spent / budget.monthlyAmount;
    final overBudget = remaining < 0;
    final totalDays = budget.totalDays < 1 ? 1 : budget.totalDays;
    final daysLeft = budget.daysRemaining(now);
    final dayNumber = (totalDays - daysLeft + 1).clamp(1, totalDays);
    final s = CurrencyFormatter.symbolFor(budget.currency);
    String money(double v) =>
        CurrencyFormatter.format(v, code: budget.currency, decimalDigits: 0);

    return ListView(
      padding: AppSpacing.pagePaddingWithFab,
      children: [
        // Header
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.mlg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconTile(
                    icon: BudgetVisuals.iconFor(budget.icon),
                    color: accent,
                    size: AppSizes.avatarLg,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          budget.name,
                          style: theme.textTheme.titleLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          formatDateRange(budget.startDate, budget.endDate),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _statusChip(context, phase),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                overBudget ? 'Over budget by' : 'Remaining',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AnimatedAmount(
                      amount: remaining.abs(),
                      currency: budget.currency,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: overBudget
                            ? colors.error
                            : theme.colorScheme.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'of ${money(budget.monthlyAmount)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.smd),
              Row(
                children: [
                  Expanded(
                    child: AppProgress(
                      value: utilization,
                      semanticLabel: 'Budget used',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${(utilization * 100).clamp(0, 999).toStringAsFixed(0)}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: overBudget
                          ? colors.error
                          : AppProgress.colorFor(context, utilization),
                    ),
                  ),
                  InfoIcon(
                    content: InfoContent(
                      title: 'Budget progress',
                      whatIsThis:
                          "How much of this budget's total amount has been "
                          "spent so far in its period. This is different from "
                          "Today's Safe Spending, which only looks at today.",
                      howIsItCalculated:
                          'Progress = Total spent ÷ Budget amount\n'
                          'Remaining = Budget amount − Total spent\n\n'
                          'Total spent counts every expense recorded in this '
                          'budget.',
                      example:
                          'Budget amount: ${s}30,000\n'
                          'Total spent: ${s}18,000\n'
                          'Progress: 60% · Remaining: ${s}12,000',
                      additionalNotes:
                          "• Uses this budget's own amount and expenses only\n"
                          '• The period runs from the start date to the end '
                          'date you chose; it does not have to be a calendar '
                          'month\n'
                          '• The bar stops at 100% even if you spend more '
                          'than the budget amount',
                    ),
                  ),
                ],
              ),
              if (budget.notes != null && budget.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  budget.notes!.trim(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Not-active / archived banner. Collapses smoothly when the budget
        // is made active or restored instead of vanishing.
        AnimatedSize(
          duration: AppMotion.respectReducedMotion(context, AppMotion.medium),
          curve: AppMotion.standardCurve,
          alignment: Alignment.topCenter,
          child: (budget.isArchived || !isActive)
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.smd),
                  child: StatusCard(
                    color: budget.isArchived
                        ? theme.colorScheme.onSurfaceVariant
                        : colors.info,
                    icon: budget.isArchived
                        ? Icons.archive_outlined
                        : Icons.info_outline_rounded,
                    message: budget.isArchived
                        ? 'This budget is archived. Restore it to record '
                              'expenses again.'
                        : 'Not the active budget. Home, Expenses and Reports '
                              'show the active budget.',
                    trailing: budget.isArchived
                        ? TextButton(
                            onPressed: busy ? null : onRestore,
                            child: const Text('Restore'),
                          )
                        : TextButton(
                            onPressed: busy ? null : onSetActive,
                            child: const Text('Make active'),
                          ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),

        // Stats
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final tiles = [
              _StatTile(
                icon: Icons.payments_outlined,
                label: 'Spent',
                value: money(spent),
              ),
              _StatTile(
                icon: Icons.today_outlined,
                label: 'Spent today',
                value: money(stats.todaySpending),
              ),
              _StatTile(
                icon: Icons.receipt_long_outlined,
                label: 'Expenses',
                value: '${stats.expenseCount}',
              ),
              _StatTile(
                icon: Icons.timelapse_rounded,
                label: phase == BudgetPhase.running
                    ? 'Days left'
                    : phase == BudgetPhase.upcoming
                    ? 'Starts in'
                    : 'Period',
                value: phase == BudgetPhase.running
                    ? '$daysLeft'
                    : phase == BudgetPhase.upcoming
                    ? '${budget.startDate.difference(now).inDays + 1} days'
                    : 'Ended',
                caption: phase == BudgetPhase.running
                    ? 'Day $dayNumber of $totalDays'
                    : null,
              ),
            ];
            final columns = constraints.maxWidth >= 520 ? 4 : 2;
            final width =
                (constraints.maxWidth - AppSpacing.sm * (columns - 1)) /
                columns;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final t in tiles) SizedBox(width: width, child: t),
              ],
            );
          },
        ),

        // Navigation to this budget's data (only meaningful when active).
        if (isActive && !budget.isArchived) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/app/expenses'),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Expenses'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/app/reports'),
                  icon: const Icon(Icons.insights_outlined),
                  label: const Text('Reports'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _statusChip(BuildContext context, BudgetPhase phase) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    if (budget.isArchived) {
      return StatusChip(
        label: 'Archived',
        color: theme.colorScheme.onSurfaceVariant,
        icon: Icons.archive_rounded,
      );
    }
    if (isActive) {
      return StatusChip(
        label: 'Active',
        color: theme.colorScheme.primary,
        icon: Icons.check_circle_rounded,
      );
    }
    return switch (phase) {
      BudgetPhase.upcoming => StatusChip(
        label: 'Upcoming',
        color: colors.info,
        icon: Icons.schedule_rounded,
      ),
      BudgetPhase.ended => StatusChip(
        label: 'Ended',
        color: theme.colorScheme.onSurfaceVariant,
        icon: Icons.event_busy_rounded,
      ),
      _ => StatusChip(
        label: 'Inactive',
        color: theme.colorScheme.onSurfaceVariant,
        icon: Icons.radio_button_off_rounded,
      ),
    };
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? caption;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.smd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: AppSizes.iconSm,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              maxLines: 1,
            ),
          ),
          if (caption != null)
            Text(
              caption!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

/// Owns its text controller so it outlives the dialog's exit animation; a
/// controller disposed the moment the dialog returns is still in use by the
/// field while the dialog fades out.
class _DuplicateBudgetDialog extends StatefulWidget {
  final String initialName;

  const _DuplicateBudgetDialog({required this.initialName});

  @override
  State<_DuplicateBudgetDialog> createState() => _DuplicateBudgetDialogState();
}

class _DuplicateBudgetDialogState extends State<_DuplicateBudgetDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Duplicate budget'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'New budget name'),
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Duplicate'),
        ),
      ],
    );
  }
}
