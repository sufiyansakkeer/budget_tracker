import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../domain/usecases/manage_budget_usecase.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/events/refresh_bus.dart';

/// A tappable control that shows the active budget's name and period and
/// opens the budget switcher.
///
/// It listens to [RefreshBuses.budgets] so it stays in sync when the active budget
/// changes anywhere in the app. Use [ActiveBudgetSelector.open] to show the
/// switcher from elsewhere on the same screen.
class ActiveBudgetSelector extends StatefulWidget {
  const ActiveBudgetSelector({super.key});

  /// Opens the budget switcher sheet and applies the chosen action.
  static Future<void> open(BuildContext context) async {
    final manageBudget = getIt<ManageBudgetUseCase>();
    final budgets = await manageBudget.getAll();
    final activeId = await manageBudget.activeBudgetId();
    if (!context.mounted) return;

    final action = await AppBottomSheet.show<BudgetAction>(
      context: context,
      builder: (context) =>
          _BudgetSwitcherSheet(budgets: budgets, activeId: activeId),
    );
    if (action == null || !context.mounted) return;

    switch (action.type) {
      case BudgetActionType.create:
        await context.push('/app/budgets/create');
        RefreshBuses.budgets.notifyChanged();
      case BudgetActionType.open:
        await context.push('/app/budgets/${action.budget!.id}');
      case BudgetActionType.manage:
        await context.push('/app/budgets');
        RefreshBuses.budgets.notifyChanged();
      case BudgetActionType.select:
        final budget = action.budget!;
        if (budget.isArchived || budget.id == activeId) return;
        await manageBudget.setActive(budget.id);
        RefreshBuses.budgets.notifyChanged();
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
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final budget = _active;

    if (_loading) {
      return const Shimmer(
        child: SkeletonBox(height: 56, radius: AppSpacing.radiusMd),
      );
    }

    return Semantics(
      button: true,
      label: budget == null
          ? 'Choose a budget'
          : 'Active budget ${budget.name}, '
                '${formatDateRange(budget.startDate, budget.endDate)}. '
                'Tap to switch budget',
      child: ExcludeSemantics(
        child: AppCard(
          onTap: () => ActiveBudgetSelector.open(context),
          borderRadius: AppSpacing.borderRadiusMd,
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
                    alignment: Alignment.centerLeft,
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
                        budget?.name ?? 'Choose a budget',
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        budget == null
                            ? 'No active budget selected'
                            : formatDateRange(budget.startDate, budget.endDate),
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
                Icons.unfold_more_rounded,
                size: AppSizes.iconMd,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Switcher sheet ─────────────────────────────────────────────────────────

class _BudgetSwitcherSheet extends StatelessWidget {
  final List<BudgetEntity> budgets;
  final String? activeId;

  const _BudgetSwitcherSheet({required this.budgets, required this.activeId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = budgets.where((b) => !b.isArchived || b.id == activeId);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSheetHeader(
          title: 'Switch budget',
          subtitle: 'Home, Expenses and Reports follow the active budget.',
        ),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Text(
              'You have no budgets yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              children: [
                for (final budget in visible)
                  _BudgetRow(
                    budget: budget,
                    isActive: budget.id == activeId,
                    onSelect: () =>
                        Navigator.of(context).pop(BudgetAction.select(budget)),
                    onOpen: () =>
                        Navigator.of(context).pop(BudgetAction.open(budget)),
                  ),
              ],
            ),
          ),
        const Divider(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () =>
                      Navigator.of(context).pop(const BudgetAction.create()),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New budget'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(const BudgetAction.manage()),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Manage'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final BudgetEntity budget;
  final bool isActive;
  final VoidCallback onSelect;
  final VoidCallback onOpen;

  const _BudgetRow({
    required this.budget,
    required this.isActive,
    required this.onSelect,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final runningToday = budget.isActiveOn(today);
    final subtitleParts = <String>[
      formatShortDateRange(budget.startDate, budget.endDate),
      if (budget.isArchived)
        'Archived'
      else if (!runningToday)
        today.isBefore(budget.startDate) ? 'Starts later' : 'Ended',
    ];

    return ListTile(
      onTap: budget.isArchived ? null : onSelect,
      enabled: !budget.isArchived,
      selected: isActive,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.5,
      ),
      leading: Icon(
        isActive
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_off_rounded,
        color: isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        budget.name,
        style: theme.textTheme.titleSmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(subtitleParts.join(' · ')),
      trailing: IconButton(
        tooltip: 'Budget details',
        icon: const Icon(Icons.chevron_right_rounded),
        onPressed: onOpen,
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
