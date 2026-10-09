import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_metric.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_notice.dart';
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../bills/domain/entities/bill_entity.dart';
import '../../../bills/domain/entities/bill_failure.dart';
import '../../../bills/domain/usecases/get_bills_usecase.dart';
import '../../domain/entities/monthly_statistics_entity.dart';
import '../../domain/repository/budget_repository.dart';
import '../../domain/usecases/manage_budget_usecase.dart';
import '../../../expenses/presentation/quick_add/quick_add_sheet.dart';
import '../widgets/budget_list_items.dart';
import '../widgets/budget_visuals.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_fab.dart';
import '../../../../core/events/refresh_bus.dart';
import '../../../../core/navigation/push_unique.dart';
import '../../../../core/widgets/app_animated_size.dart';

/// Entry point for a selected budget: what is left on one surface (bar
/// with a tick for today, the period, spent, spent today, expenses), then
/// what the budget means for the rest of the app. Actions: edit, set active,
/// archive, duplicate and delete; "Add expense" only on the active budget,
/// since that is where quick add records, and "Make active" on any other.
class BudgetDetailsScreen extends StatefulWidget {
  final String budgetId;

  const BudgetDetailsScreen({super.key, required this.budgetId});

  /// "Now" for the period and day counts; replaced in golden tests.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

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
        _error = "It's still on this device. Try again in a moment.";
      });
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Runs one of the budget's actions; [failed] names what didn't happen.
  Future<void> _run(
    Future<void> Function() action, {
    required String failed,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      debugPrint('[error] $failed: $e');
      if (mounted) _notify('$failed Try again.');
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
  }, failed: "Couldn't make this budget active.");

  /// Bills linked to this budget, for the archive and delete confirmations.
  /// Best effort: on failure the dialogs just don't mention bills.
  Future<List<BillEntity>> _linkedBills() async {
    try {
      final result = await getIt<GetBillsUseCase>()();
      if (result case BillSuccess(:final data)) {
        return data.where((b) => b.budgetId == widget.budgetId).toList();
      }
    } catch (_) {
      // Fall through.
    }
    return const [];
  }

  static String _bills(int count) => count == 1 ? 'bill' : 'bills';

  Future<void> _archive() async {
    // Archiving stops the budget setting its bills aside, so ask first when
    // it has unpaid ones; otherwise archive straight away as before.
    final unpaid = (await _linkedBills()).where((b) => !b.isPaid).length;
    if (!mounted) return;
    if (unpaid > 0) {
      final confirmed = await ConfirmationDialog.show(
        context: context,
        title: 'Archive this budget?',
        message:
            '"${_budget?.name}" will be archived; its expenses are kept. '
            '$unpaid unpaid ${_bills(unpaid)} paid from it will no longer be '
            'set aside until you link ${unpaid == 1 ? 'it' : 'them'} to '
            'another budget.',
        confirmLabel: 'Archive',
        icon: Icons.archive_outlined,
      );
      if (!confirmed || !mounted) return;
    }
    await _run(() async {
      await _manageBudget.archive(widget.budgetId, archived: true);
      RefreshBuses.budgets.notifyChanged();
      if (!mounted) return;
      setState(() => _budget = _budget?.copyWith(isArchived: true));
      _notify('Budget archived');
    }, failed: "Couldn't archive the budget.");
  }

  Future<void> _restore() => _run(() async {
    await _manageBudget.archive(widget.budgetId, archived: false);
    RefreshBuses.budgets.notifyChanged();
    if (!mounted) return;
    setState(() => _budget = _budget?.copyWith(isArchived: false));
    _notify('Budget restored');
  }, failed: "Couldn't restore the budget.");

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
    }, failed: "Couldn't duplicate the budget.");
  }

  Future<void> _delete() async {
    final linked = (await _linkedBills()).length;
    if (!mounted) return;
    final billsLine = linked == 0
        ? ''
        : ' $linked ${_bills(linked)} paid from it will become not linked.';
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Delete this budget?',
      message:
          'This permanently deletes "${_budget?.name}" and every expense '
          'recorded in it.$billsLine This cannot be undone.',
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
    }, failed: "Couldn't delete the budget.");
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
      // Adding goes to the active budget, so only the active budget offers
      // it (review: from another budget it recorded into the active one).
      // Any other budget offers to become active instead.
      floatingActionButton: budget == null || budget.isArchived
          ? null
          : _isActive
          ? AppFab(
              key: const Key('budgetAddExpense'),
              heroTag: 'budget_details_fab',
              onPressed: _busy ? null : () => QuickAddSheet.show(context),
              icon: Icons.add_rounded,
              label: 'Add expense',
            )
          : AppFab(
              key: const Key('budgetMakeActive'),
              heroTag: 'budget_details_fab',
              onPressed: _busy ? null : _setActive,
              icon: Icons.check_circle_outline_rounded,
              label: 'Make active',
              tooltip: 'Make this the active budget',
            ),
    );
  }

  Widget _body() {
    if (_loading) return const FormSkeleton(key: ValueKey('loading'), rows: 4);
    if (_error != null) {
      return ErrorState(
        key: const ValueKey('error'),
        title: "Couldn't load this budget",
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
      onRestore: _restore,
    );
  }
}

class _Content extends StatelessWidget {
  final BudgetEntity budget;
  final MonthlyStatisticsEntity stats;
  final bool isActive;
  final bool busy;
  final VoidCallback onRestore;

  const _Content({
    super.key,
    required this.budget,
    required this.stats,
    required this.isActive,
    required this.busy,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typography = context.appTypography;
    final now = BudgetDetailsScreen.clock();
    final spent = stats.totalSpent;
    final remaining = budget.monthlyAmount - spent;
    final over = remaining < 0;
    final used = budget.monthlyAmount <= 0 ? 0.0 : spent / budget.monthlyAmount;
    final s = CurrencyFormatter.symbolFor(budget.currency);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final progressParts = [
      '${(used * 100).clamp(0, 999).round()}% used',
      ?BudgetPeriodCopy.dayOf(budget, now),
      BudgetPeriodCopy.when(budget, now),
    ];

    return ListView(
      padding: AppSpacing.pagePaddingWithFab,
      children: [
        AppSurface(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.mlg,
            AppSpacing.mlg,
            AppSpacing.mlg,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconTile(
                    icon: BudgetVisuals.iconFor(budget.icon),
                    color: BudgetVisuals.colorFor(context, budget),
                  ),
                  const SizedBox(width: AppSpacing.smd),
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
                        Text(
                          formatDateRange(budget.startDate, budget.endDate),
                          style: muted,
                        ),
                        // Under the name rather than beside it, so a long
                        // name keeps its width at large text sizes.
                        const SizedBox(height: AppSpacing.xs),
                        _statusChip(budget.phaseOn(now)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.mlg),
              Text(
                over ? 'Over by' : 'Left',
                style: typography.eyebrow.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              AppMoney(
                amount: remaining.abs(),
                currency: budget.currency,
                role: MoneyRole.display,
                color: over ? context.tone(AppTone.critical).accent : null,
              ),
              Text(
                'of ${AppMoney.format(budget.monthlyAmount, currency: budget.currency)}',
                style: muted,
              ),
              const SizedBox(height: AppSpacing.smd),
              BudgetUsageTrack(
                budget: budget.copyWith(remainingAmount: remaining),
                now: now,
                height: AppSizes.progressSm,
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(progressParts.join(' · '), style: muted),
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
                          'than the budget amount; the tick marks today',
                    ),
                  ),
                ],
              ),
              Divider(color: theme.colorScheme.outlineVariant),
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppMetric(
                      label: 'Spent',
                      value: AppMoney(
                        amount: spent,
                        currency: budget.currency,
                        role: MoneyRole.body,
                      ),
                    ),
                  ),
                  Expanded(
                    child: AppMetric(
                      label: 'Spent today',
                      value: AppMoney(
                        amount: stats.todaySpending,
                        currency: budget.currency,
                        role: MoneyRole.body,
                      ),
                    ),
                  ),
                  Expanded(
                    child: AppMetric(
                      label: 'Expenses',
                      alignEnd: true,
                      value: Text(
                        '${stats.expenseCount}',
                        style: typography.moneyBody,
                      ),
                    ),
                  ),
                ],
              ),
              if (budget.notes != null && budget.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(budget.notes!.trim(), style: muted),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // What this budget means for the rest of the app. Changes ease in
        // rather than snapping when it is made active or restored.
        AppAnimatedSize(
          duration: AppMotion.respectReducedMotion(context, AppMotion.medium),
          curve: AppMotion.standardCurve,
          alignment: Alignment.topCenter,
          child: budget.isArchived
              ? AppNotice(
                  key: const ValueKey('archivedNotice'),
                  tone: AppTone.neutral,
                  icon: Icons.archive_outlined,
                  title: 'Archived',
                  message: 'Restore it to record expenses again.',
                  action: TextButton(
                    onPressed: busy ? null : onRestore,
                    child: const Text('Restore'),
                  ),
                )
              : !isActive
              ? AppNotice(
                  key: const ValueKey('inactiveNotice'),
                  tone: AppTone.info,
                  icon: Icons.info_outline_rounded,
                  title: 'Not your active budget',
                  // "Make active" is the screen's button below; the note
                  // only says why it is there.
                  message:
                      'Home, Expenses and Reports show the active budget. '
                      'Make this one active to follow it there and add '
                      'expenses to it.',
                )
              : Column(
                  key: const ValueKey('activeLinks'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Home, Expenses and Reports follow this budget',
                      style: muted,
                    ),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        TextButton.icon(
                          onPressed: () => context.go('/app/expenses'),
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: const Text('Expenses'),
                        ),
                        TextButton.icon(
                          onPressed: () => context.go('/app/reports'),
                          icon: const Icon(Icons.insights_outlined),
                          label: const Text('Reports'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _statusChip(BudgetPhase phase) {
    if (budget.isArchived) {
      return const StatusChip.tone(
        wrapLabel: true,
        label: 'Archived',
        tone: AppTone.neutral,
        icon: Icons.archive_rounded,
      );
    }
    if (isActive) {
      return const StatusChip.tone(
        wrapLabel: true,
        label: 'Active',
        tone: AppTone.positive,
        icon: Icons.check_circle_rounded,
      );
    }
    return switch (phase) {
      BudgetPhase.upcoming => const StatusChip.tone(
        wrapLabel: true,
        label: 'Upcoming',
        tone: AppTone.info,
        icon: Icons.schedule_rounded,
      ),
      BudgetPhase.ended => const StatusChip.tone(
        wrapLabel: true,
        label: 'Ended',
        tone: AppTone.neutral,
        icon: Icons.event_busy_rounded,
      ),
      _ => const StatusChip.tone(
        wrapLabel: true,
        label: 'Not active',
        tone: AppTone.neutral,
        icon: Icons.radio_button_off_rounded,
      ),
    };
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
