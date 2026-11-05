import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/currency/money_math.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/dates/date_range_format.dart';
import '../../../../core/widgets/app_list.dart';
import '../../../../core/widgets/app_metric.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_notice.dart';
import '../../../../core/widgets/app_page_body.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../bills/domain/entities/bill_entity.dart';
import '../../../bills/domain/entities/bill_failure.dart';
import '../../../bills/domain/usecases/get_bills_usecase.dart';
import '../../../dashboard/domain/usecases/get_safe_to_spend_usecase.dart';
import '../../domain/entities/budget_error.dart';
import '../../domain/entities/monthly_statistics_entity.dart';
import '../../domain/entities/safe_to_spend/safe_to_spend_entity.dart';
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
/// what it sets aside from Today's Safe Spending, then what the budget means
/// for the rest of the app. Actions: edit, set active, archive, duplicate
/// and delete; "Add expense" only on the active budget, since that is where
/// quick add records, and "Make active" on any other; "Start next period"
/// once it has ended.
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

  /// The engine's result for this budget, for what it sets aside; null when
  /// it couldn't be worked out.
  SafeToSpendEntity? _safeToSpend;
  bool _isActive = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  StreamSubscription<void>? _expenseSubscription;
  StreamSubscription<void>? _budgetSubscription;

  /// Set while a delete runs: the delete notifies the buses, and reloading a
  /// budget that no longer exists would flash "Budget not found" during the
  /// pop animation. A failed delete clears it, so the screen stays live.
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
    _expenseSubscription = RefreshBuses.expenses.changes.listen((_) {
      if (mounted && !_deleting) _load(silent: true);
    });
    _budgetSubscription = RefreshBuses.budgets.changes.listen((_) {
      if (mounted && !_deleting) _load(silent: true);
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
      final safeToSpend = budget == null
          ? null
          : await _readSafeToSpend(budget.id);
      if (!mounted) return;
      setState(() {
        _budget = budget;
        _stats = stats;
        _safeToSpend = safeToSpend;
        _isActive = budget != null && budget.id == activeId;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('[error] Loading budget ${widget.budgetId}: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "It's still on this device. Try again in a moment.";
      });
    }
  }

  /// Best effort: without it the "Set aside" group shows the budget's own
  /// amounts and leaves bills out.
  Future<SafeToSpendEntity?> _readSafeToSpend(String budgetId) async {
    if (!getIt.isRegistered<GetSafeToSpendUseCase>()) return null;
    try {
      final result = await getIt<GetSafeToSpendUseCase>()(
        budgetId: budgetId,
        referenceDate: BudgetDetailsScreen.clock(),
      );
      if (result case BudgetSuccess(:final data)) return data;
    } catch (e) {
      debugPrint('[error] Working out what budget $budgetId sets aside: $e');
    }
    return null;
  }

  /// The other budgets, the most recently started first (the repository's
  /// order).
  List<BudgetEntity> _othersNewestFirst(List<BudgetEntity> all) => [
    for (final b in all)
      if (b.id != widget.budgetId) b,
  ]..sort((a, b) => b.startDate.compareTo(a.startDate));

  /// Another budget in use that runs today, to switch to on archiving.
  BudgetEntity? _runningOther(List<BudgetEntity> all) {
    final now = BudgetDetailsScreen.clock();
    for (final b in _othersNewestFirst(all)) {
      if (!b.isArchived && b.isActiveOn(now)) return b;
    }
    return null;
  }

  /// Which budget becomes active once this one is deleted, as
  /// `BudgetRepositoryImpl.getActiveBudgetId` picks it: one in use running
  /// today, else the latest started in use, else the latest started.
  BudgetEntity? _successorIfDeleted(List<BudgetEntity> all) {
    final others = _othersNewestFirst(all);
    final inUse = others.where((b) => !b.isArchived).toList();
    final candidates = inUse.isEmpty ? others : inUse;
    if (candidates.isEmpty) return null;
    final now = BudgetDetailsScreen.clock();
    return candidates.firstWhere(
      (b) => b.isActiveOn(now),
      orElse: () => candidates.first,
    );
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
    } catch (e) {
      debugPrint('[error] Loading bills linked to a budget: $e');
    }
    return const [];
  }

  static String _bills(int count) => count == 1 ? 'bill' : 'bills';

  Future<void> _archive() async {
    // Archiving stops the budget setting its bills aside, and the active
    // budget stays active (Home loses its daily figure), so ask first in
    // either case; otherwise archive straight away, with Undo.
    final unpaid = (await _linkedBills()).where((b) => !b.isPaid).length;
    final billsLine = unpaid == 0
        ? ''
        : ' $unpaid unpaid ${_bills(unpaid)} paid from it will no longer be '
              'set aside until you link ${unpaid == 1 ? 'it' : 'them'} to '
              'another budget.';
    if (!mounted) return;
    BudgetEntity? switchTo;
    if (_isActive) {
      try {
        switchTo = _runningOther(await _manageBudget.getAll());
      } catch (e) {
        // Then only plain Archive is offered.
        debugPrint('[error] Loading budgets to switch to: $e');
      }
      if (!mounted) return;
      final choice = await AppDialog.show<_ArchiveChoice>(
        context: context,
        builder: (context) => _ArchiveActiveDialog(
          name: _budget!.name,
          billsLine: billsLine,
          switchTo: switchTo?.name,
        ),
      );
      if (choice == null || !mounted) return;
      if (choice == _ArchiveChoice.archive) switchTo = null;
    } else if (unpaid > 0) {
      final confirmed = await ConfirmationDialog.show(
        context: context,
        title: 'Archive this budget?',
        message:
            '"${_budget?.name}" will be archived; its expenses are '
            'kept.$billsLine',
        confirmLabel: 'Archive',
        icon: Icons.archive_outlined,
      );
      if (!confirmed || !mounted) return;
    }
    final next = switchTo;
    await _run(() async {
      await _manageBudget.archive(widget.budgetId, archived: true);
      if (next != null) await _manageBudget.setActive(next.id);
      RefreshBuses.budgets.notifyChanged();
      if (!mounted) return;
      setState(() {
        _budget = _budget?.copyWith(isArchived: true);
        if (next != null) _isActive = false;
      });
      _offerUndoArchive(
        next == null
            ? 'Budget archived'
            : 'Budget archived. ${next.name} is now active.',
        switchedAway: next != null,
      );
    }, failed: "Couldn't archive the budget.");
  }

  /// [message] with Undo, which restores the budget and, when archiving
  /// switched away from it, makes it active again. Outlives the screen, so
  /// it holds what it needs.
  void _offerUndoArchive(String message, {required bool switchedAway}) {
    final manageBudget = _manageBudget;
    final id = widget.budgetId;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              String done;
              try {
                await manageBudget.archive(id, archived: false);
                if (switchedAway) await manageBudget.setActive(id);
                RefreshBuses.budgets.notifyChanged();
                done = 'Budget restored';
              } catch (e) {
                debugPrint('[error] Undoing an archive: $e');
                done = "Couldn't restore the budget. Try again.";
              }
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(done)));
            },
          ),
        ),
      );
  }

  Future<void> _restore() => _run(() async {
    await _manageBudget.archive(widget.budgetId, archived: false);
    RefreshBuses.budgets.notifyChanged();
    if (!mounted) return;
    setState(() => _budget = _budget?.copyWith(isArchived: false));
    _notify('Budget restored');
  }, failed: "Couldn't restore the budget.");

  Future<void> _duplicate() async {
    final budget = _budget!;
    final name = await AppDialog.show<String>(
      context: context,
      builder: (context) => _DuplicateBudgetDialog(
        initialName: '${budget.name} (Copy)',
        dates: formatDateRange(budget.startDate, budget.endDate),
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    await _run(() async {
      final copy = await _manageBudget.duplicate(
        widget.budgetId,
        newName: name,
      );
      RefreshBuses.budgets.notifyChanged();
      if (!mounted) return;
      _notify('Created "$name"');
      context.pushUnique('/app/budgets/${copy.id}');
    }, failed: "Couldn't duplicate the budget.");
  }

  /// Purchases on Pay later tabs inside this budget, for the delete
  /// confirmation. Null when they can't be counted: the dialog then just
  /// doesn't mention them.
  Future<int?> _tabPurchases() async {
    try {
      return await _manageBudget.tabPurchasesIn(widget.budgetId);
    } catch (e) {
      debugPrint('[error] Counting Pay later purchases in a budget: $e');
      return null;
    }
  }

  static String _tabsLine(int count) => count == 1
      ? ' 1 purchase on a Pay later tab will be removed from its tab; any '
            'money paid on it moves to other purchases or stays as credit.'
      : ' $count purchases on Pay later tabs will be removed from their '
            'tabs; any money paid on them moves to other purchases or stays '
            'as credit.';

  Future<void> _delete() async {
    final linked = (await _linkedBills()).length;
    final tabPurchases = await _tabPurchases();
    if (!mounted) return;
    final billsLine = linked == 0
        ? ''
        : ' $linked ${_bills(linked)} paid from it will become not linked.';
    final tabsLine = (tabPurchases ?? 0) == 0 ? '' : _tabsLine(tabPurchases!);
    // Deleting the active budget hands "active" to another one; say which.
    final wasActive = _isActive;
    var switchLine = '';
    if (wasActive) {
      try {
        final next = _successorIfDeleted(await _manageBudget.getAll());
        switchLine = next == null
            ? ' Home will have no budget until you create one.'
            : ' Home will switch to "${next.name}".';
      } catch (e) {
        debugPrint('[error] Loading budgets for the delete confirmation: $e');
      }
    }
    if (!mounted) return;
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Delete this budget?',
      message:
          'This permanently deletes "${_budget?.name}" and every expense '
          'recorded in it.$billsLine$tabsLine$switchLine This cannot be '
          'undone.',
      confirmLabel: 'Delete',
      icon: Icons.delete_forever_rounded,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    await _run(() async {
      _deleting = true;
      try {
        await _manageBudget.delete(widget.budgetId);
      } catch (_) {
        _deleting = false;
        rethrow;
      }
      RefreshBuses.budgets.notifyChanged();
      // Tabs that had a purchase in the budget were reconciled; when the
      // count failed, tell Pay later screens anyway.
      if (tabPurchases != 0) RefreshBuses.payLater.notifyChanged();
      final now = wasActive ? await _activeAfterDelete() : null;
      if (!mounted) return;
      _notify(
        now == null ? 'Budget deleted' : 'Budget deleted. $now is now active.',
      );
      context.pop(true);
    }, failed: "Couldn't delete the budget.");
  }

  /// The name of the budget that became active after a delete; null when
  /// there is none or it can't be read.
  Future<String?> _activeAfterDelete() async {
    try {
      final id = await _manageBudget.activeBudgetId();
      return id == null ? null : (await _manageBudget.getById(id))?.name;
    } catch (e) {
      debugPrint('[error] Reading the active budget after a delete: $e');
      return null;
    }
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
      safeToSpend: _safeToSpend,
      isActive: _isActive,
      busy: _busy,
      onRestore: _restore,
    );
  }
}

class _Content extends StatelessWidget {
  final BudgetEntity budget;
  final MonthlyStatisticsEntity stats;
  final SafeToSpendEntity? safeToSpend;
  final bool isActive;
  final bool busy;
  final VoidCallback onRestore;

  const _Content({
    super.key,
    required this.budget,
    required this.stats,
    required this.safeToSpend,
    required this.isActive,
    required this.busy,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typography = context.appTypography;
    final now = BudgetDetailsScreen.clock();
    final phase = budget.phaseOn(now);
    final spent = stats.totalSpent;
    final remaining = MoneyMath.forCurrency(
      budget.currency,
    ).subtract(budget.monthlyAmount, spent);
    final over = remaining < 0;
    final used = budget.monthlyAmount <= 0 ? 0.0 : spent / budget.monthlyAmount;
    final s = CurrencyFormatter.symbolFor(budget.currency);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final progressParts = [
      '${(used * 100).clamp(0, 999).round()}% used',
      ?BudgetPeriodCopy.dayOf(budget, now),
      BudgetPeriodCopy.when(budget, now, withToday: true),
    ];

    return AppPageBody(
      padding: AppSpacing.pagePaddingWithFab,
      builder: (context, padding) => ListView(
        padding: padding,
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
                          BudgetStatusChip(
                            budget: budget,
                            isActive: isActive,
                            now: now,
                          ),
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
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  children: [
                    Text(
                      'of ${AppMoney.format(budget.monthlyAmount, currency: budget.currency)}',
                      style: muted,
                    ),
                    // The amount is changed in the edit form, beside it.
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => context.pushUnique(
                              '/app/budgets/${budget.id}/edit',
                            ),
                      child: const Text('Change amount'),
                    ),
                  ],
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
                            'Total spent counts every expense dated inside '
                            "this budget's period.",
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
                // Side by side, or stacked at large text (UX-054).
                AppMetricRow(
                  metrics: [
                    AppMetric(
                      label: 'Spent',
                      value: AppMoney(
                        amount: spent,
                        currency: budget.currency,
                        role: MoneyRole.body,
                      ),
                    ),
                    AppMetric(
                      // Every expense today, bill payments too; Home's
                      // "Spent today" leaves those out.
                      label: 'Spent today, incl. bills',
                      value: AppMoney(
                        amount: stats.todaySpending,
                        currency: budget.currency,
                        role: MoneyRole.body,
                      ),
                    ),
                    AppMetric(
                      label: 'Expenses',
                      alignEnd: true,
                      value: Text(
                        '${stats.expenseCount}',
                        style: typography.moneyBody,
                      ),
                    ),
                  ],
                ),
                if (budget.notes != null &&
                    budget.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(budget.notes!.trim(), style: muted),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SetAsideGroup(
            budget: budget,
            safeToSpend: safeToSpend,
            linkToHome: isActive && phase == BudgetPhase.running,
          ),
          const SizedBox(height: AppSpacing.lg),

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
                : phase == BudgetPhase.ended
                ? Column(
                    key: ValueKey('endedNotice_$isActive'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      EndedBudgetNotice(budget: budget, isActive: isActive),
                      if (isActive) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _activeLinks(context, muted),
                      ],
                    ],
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
                : _activeLinks(context, muted),
          ),
        ],
      ),
    );
  }

  Widget _activeLinks(BuildContext context, TextStyle? muted) => Column(
    key: const ValueKey('activeLinks'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Home, Expenses and Reports follow this budget', style: muted),
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
  );
}

/// What the budget keeps out of Today's Safe Spending, read-only: money kept
/// aside, the savings goal and bills still due, as the engine has them.
/// The daily figure itself stays on Home.
class _SetAsideGroup extends StatelessWidget {
  final BudgetEntity budget;
  final SafeToSpendEntity? safeToSpend;
  final bool linkToHome;

  const _SetAsideGroup({
    required this.budget,
    required this.safeToSpend,
    required this.linkToHome,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final e = safeToSpend;
    Widget money(double? amount, {String none = 'Not set'}) => amount == null
        ? Text(none, style: muted, textAlign: TextAlign.end)
        : AppMoney(
            amount: amount,
            currency: budget.currency,
            textAlign: TextAlign.end,
          );
    return AppSection(
      title: 'Set aside',
      subtitle: "Kept out of Today's Safe Spending",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppGroupedList(
            children: [
              AppListRow(
                title: 'Kept aside',
                trailing: money(
                  e == null ? budget.reservedAmount : e.reservedAmount,
                ),
              ),
              AppListRow(
                title: 'Savings goal',
                trailing: money(
                  e == null ? budget.savingsTarget : e.savingsTarget,
                ),
              ),
              if (e != null && e.commitmentsAvailable)
                AppListRow(
                  title: 'Bills due',
                  trailing: e.upcomingCommitments > 0
                      ? money(e.upcomingCommitments)
                      : Text('None', style: muted, textAlign: TextAlign.end),
                ),
            ],
          ),
          if (linkToHome)
            TextButton(
              onPressed: () => context.go('/app/home'),
              child: const Text("See Today's Safe Spending on Home"),
            ),
        ],
      ),
    );
  }
}

enum _ArchiveChoice { archive, archiveAndSwitch }

/// Archiving the active budget: it stays active, so Home loses its daily
/// figure. Offers to switch to [switchTo], a budget running today, instead.
class _ArchiveActiveDialog extends StatelessWidget {
  final String name;
  final String billsLine;
  final String? switchTo;

  const _ArchiveActiveDialog({
    required this.name,
    required this.billsLine,
    required this.switchTo,
  });

  @override
  Widget build(BuildContext context) {
    final other = switchTo;
    return AlertDialog(
      icon: Icon(
        Icons.archive_outlined,
        color: Theme.of(context).colorScheme.primary,
        size: 32,
      ),
      title: const Text(
        'Archive your active budget?',
        textAlign: TextAlign.center,
      ),
      content: Text(
        '"$name" will be archived; its expenses are kept. Home, Expenses and '
        'Reports keep following it until you choose another budget, and '
        "Home shows no Today's Safe Spending for an archived budget."
        '$billsLine',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (other == null)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_ArchiveChoice.archive),
            child: const Text('Archive'),
          )
        else ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ArchiveChoice.archive),
            child: const Text('Archive'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_ArchiveChoice.archiveAndSwitch),
            child: Text('Archive and switch to $other'),
          ),
        ],
      ],
    );
  }
}

/// Owns its text controller so it outlives the dialog's exit animation; a
/// controller disposed the moment the dialog returns is still in use by the
/// field while the dialog fades out.
class _DuplicateBudgetDialog extends StatefulWidget {
  final String initialName;

  /// The copy's dates: the same as the budget's.
  final String dates;

  const _DuplicateBudgetDialog({
    required this.initialName,
    required this.dates,
  });

  @override
  State<_DuplicateBudgetDialog> createState() => _DuplicateBudgetDialogState();
}

class _DuplicateBudgetDialogState extends State<_DuplicateBudgetDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  )..addListener(() => setState(() {}));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _name => _controller.text.trim();

  void _submit() {
    if (_name.isNotEmpty) Navigator.of(context).pop(_name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Duplicate budget'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'New budget name'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.smd),
          Text(
            'Same dates: ${widget.dates}. To carry on after it ends, use '
            'Start next period instead.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _name.isEmpty ? null : _submit,
          child: const Text('Duplicate'),
        ),
      ],
    );
  }
}
