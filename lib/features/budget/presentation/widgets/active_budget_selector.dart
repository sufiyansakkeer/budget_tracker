import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/feedback/app_haptics.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/dates/date_range_format.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../domain/usecases/manage_budget_usecase.dart';
import 'budget_picker_sheet.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/events/refresh_bus.dart';
import '../../../../core/navigation/push_unique.dart';
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/app_surface.dart';

/// A tappable control that shows the active budget's name and period and
/// opens the budget switcher.
///
/// It listens to [RefreshBuses.budgets] so it stays in sync when the active budget
/// changes anywhere in the app. Use [ActiveBudgetSelector.open] to show the
/// switcher from elsewhere on the same screen.
class ActiveBudgetSelector extends StatefulWidget {
  const ActiveBudgetSelector({super.key});

  /// Makes [budgetId] the active budget and tells every screen.
  static Future<void> select(String budgetId) async {
    await getIt<ManageBudgetUseCase>().setActive(budgetId);
    RefreshBuses.budgets.notifyChanged();
    AppHaptics.confirm();
  }

  /// Opens the budget switcher sheet and applies the chosen action.
  static Future<void> open(BuildContext context) async {
    final manageBudget = getIt<ManageBudgetUseCase>();
    final budgets = await manageBudget.getAll();
    final activeId = await manageBudget.activeBudgetId();
    if (!context.mounted) return;

    final today = DateTime.now();
    final showCurrency = budgets.map((b) => b.currency).toSet().length > 1;
    String describe(BudgetEntity b) =>
        BudgetPickerSheet.describe(b, showCurrency: showCurrency, today: today);
    final action = await BudgetPickerSheet.show<BudgetAction>(
      context,
      title: 'Switch budget',
      subtitle: 'Home, Expenses and Reports follow the active budget.',
      // Archived budgets stay hidden, except the active one.
      budgets: [
        for (final b in budgets)
          if (!b.isArchived || b.id == activeId) b,
      ],
      selectedId: activeId,
      disabledReason: (b) => b.isArchived ? describe(b) : null,
      describe: describe,
      onPick: BudgetAction.select,
      onOpen: BudgetAction.open,
      footer: (sheetContext) => [
        FilledButton.tonalIcon(
          style: AppTheme.tonal(context),
          onPressed: () =>
              Navigator.of(sheetContext).pop(const BudgetAction.create()),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New budget'),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              Navigator.of(sheetContext).pop(const BudgetAction.manage()),
          icon: const Icon(Icons.tune_rounded),
          label: const Text('Manage'),
        ),
      ],
    );
    if (action == null || !context.mounted) return;

    switch (action.type) {
      case BudgetActionType.create:
        await context.pushUnique('/app/budgets/create');
        RefreshBuses.budgets.notifyChanged();
      case BudgetActionType.open:
        await context.pushUnique('/app/budgets/${action.budget!.id}');
      case BudgetActionType.manage:
        await context.pushUnique('/app/budgets/all');
        RefreshBuses.budgets.notifyChanged();
      case BudgetActionType.select:
        final budget = action.budget!;
        if (budget.isArchived || budget.id == activeId) return;
        await select(budget.id);
    }
  }

  @override
  State<ActiveBudgetSelector> createState() => _ActiveBudgetSelectorState();
}

class _ActiveBudgetSelectorState extends State<ActiveBudgetSelector> {
  late final ManageBudgetUseCase _manageBudget = getIt<ManageBudgetUseCase>();
  StreamSubscription<void>? _refreshSub;
  BudgetEntity? _active;
  bool _loading = true;

  /// The last read failed. With a budget already shown it stays on screen;
  /// without one the selector says it couldn't load instead of "none".
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadActive();
    _refreshSub = RefreshBuses.budgets.changes.listen((_) => _loadActive());
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    super.dispose();
  }

  Future<void> _loadActive() async {
    try {
      final active = await _manageBudget.getActive();
      if (!mounted) return;
      setState(() {
        _active = active;
        _loading = false;
        _loadFailed = false;
      });
    } catch (e) {
      debugPrint('[error] Loading the active budget: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppStateSwitcher(
      duration: AppMotion.standard,
      child: _loading
          ? const Shimmer(
              key: ValueKey('loading'),
              semanticsLabel: 'Loading budgets',
              child: SkeletonBox(height: 56, radius: AppSpacing.radiusMd),
            )
          : KeyedSubtree(
              key: const ValueKey('content'),
              child: _buildContent(context),
            ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final budget = _active;
    // Nothing to show and the read failed: retrying is the useful tap, as
    // the switcher would read the same failing data.
    final unreadable = budget == null && _loadFailed;
    final VoidCallback onTap = unreadable
        ? _loadActive
        : () => ActiveBudgetSelector.open(context);

    return Semantics(
      button: true,
      label: unreadable
          ? "Couldn't load your budget. Tap to try again"
          : budget == null
          ? 'Choose a budget'
          : 'Active budget ${budget.name}, '
                '${AppDates.range(budget.startDate, budget.endDate)}. '
                'Tap to switch budget',
      onTap: onTap,
      excludeSemantics: true,
      // A quiet, borderless row: a control, not a card among cards.
      child: AppSurface(
        level: SurfaceLevel.sunken,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.smd,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            IconTile(
              icon: Icons.account_balance_wallet_rounded,
              color: theme.colorScheme.primary,
              size: AppSizes.avatarSm,
            ),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              // Switching budgets slides the new name in rather than
              // swapping the text.
              child: AnimatedSwitcher(
                duration: AppMotion.respectReducedMotion(
                  context,
                  AppMotion.standard,
                ),
                switchInCurve: AppMotion.enter,
                switchOutCurve: AppMotion.exit,
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.passthrough,
                  alignment: AlignmentDirectional.centerStart,
                  children: [...previous, if (current != null) current],
                ),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.25),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Column(
                  key: ValueKey(budget?.id ?? 'none'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unreadable
                          ? "Couldn't load your budget"
                          : budget?.name ?? 'Choose a budget',
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      unreadable
                          ? 'Tap to try again'
                          : budget == null
                          ? 'No active budget selected'
                          : AppDates.range(budget.startDate, budget.endDate),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              unreadable ? Icons.refresh_rounded : Icons.unfold_more_rounded,
              size: AppSizes.iconMd,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

enum BudgetActionType { select, open, create, manage }

class BudgetAction {
  final BudgetActionType type;
  final BudgetEntity? budget;

  const BudgetAction(this.type, this.budget);

  factory BudgetAction.select(BudgetEntity b) =>
      BudgetAction(BudgetActionType.select, b);
  factory BudgetAction.open(BudgetEntity b) =>
      BudgetAction(BudgetActionType.open, b);
  const BudgetAction.create() : this(BudgetActionType.create, null);
  const BudgetAction.manage() : this(BudgetActionType.manage, null);
}
