import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/widgets/app_list.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../domain/entities/budget_error.dart';
import '../../domain/entities/budget_list_summary_entity.dart';
import '../../domain/usecases/get_budget_list_summary_usecase.dart';
import '../../domain/usecases/manage_budget_usecase.dart';
import '../widgets/budget_list_items.dart';
import '../widgets/budget_list_summary_card.dart';
import '../widgets/budget_visuals.dart';
import '../../../../core/widgets/app_fab.dart';
import '../../../../core/events/refresh_bus.dart';
import '../../../../core/navigation/push_unique.dart';

/// Lists all budgets. The active budget leads as the one raised card (the
/// budget Home, Expenses and Reports follow); the others are compact rows
/// grouped by where they are in their period. "Total remaining" is a quiet
/// per-currency footer, so nothing looks pooled.
class BudgetListScreen extends StatefulWidget {
  const BudgetListScreen({super.key});

  /// "Now" for periods and day counts; replaced in golden tests.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  @override
  State<BudgetListScreen> createState() => _BudgetListScreenState();
}

class _BudgetListScreenState extends State<BudgetListScreen> {
  late final ManageBudgetUseCase _manageBudget = getIt<ManageBudgetUseCase>();
  late final GetBudgetListSummaryUseCase _getSummaryUseCase =
      getIt<GetBudgetListSummaryUseCase>();
  List<BudgetEntity>? _budgets;
  BudgetListSummaryEntity? _summary;
  String? _activeBudgetId;
  bool _loading = true;
  String? _error;
  StreamSubscription<void>? _refreshSubscription;
  StreamSubscription<void>? _budgetSwitchSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshSubscription = RefreshBuses.expenses.changes.listen((_) {
      if (mounted) _load(silent: true);
    });
    _budgetSwitchSubscription = RefreshBuses.budgets.changes.listen((_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshSubscription?.cancel();
    _budgetSwitchSubscription?.cancel();
    super.dispose();
  }

  /// [silent] refreshes keep the current list on screen instead of flashing
  /// the skeleton.
  Future<void> _load({bool silent = false}) async {
    if (!silent || _budgets == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final budgets = await _manageBudget.getAll();
      final activeId = await _manageBudget.activeBudgetId();
      final summaryResult = await _getSummaryUseCase();
      if (!mounted) return;

      BudgetListSummaryEntity? summary;
      if (summaryResult case BudgetSuccess(:final data)) summary = data;

      setState(() {
        _budgets = budgets;
        _activeBudgetId = activeId;
        _summary = summary;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "They're still on this device. Try again in a moment.";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: SafeArea(
        bottom: false,
        child: AppStateSwitcher(child: _buildBody()),
      ),
      floatingActionButton: AppFab(
        heroTag: 'budgets_fab',
        onPressed: () => context.pushUnique('/app/budgets/create'),
        icon: Icons.add_rounded,
        label: 'New budget',
        tooltip: 'Create a new budget',
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Shimmer(
        key: const ValueKey('loading'),
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: AppSpacing.pagePadding,
          children: const [
            SkeletonBox(height: 64, radius: AppSpacing.radiusLg),
            SizedBox(height: AppSpacing.md),
            SkeletonBox(height: 168, radius: AppSpacing.radiusLg),
            SizedBox(height: AppSpacing.smd),
            SkeletonBox(height: 168, radius: AppSpacing.radiusLg),
          ],
        ),
      );
    }
    if (_error != null) {
      return ErrorState(
        key: const ValueKey('error'),
        title: "Couldn't load your budgets",
        message: _error!,
        onRetry: _load,
      );
    }

    final budgets = _budgets ?? const <BudgetEntity>[];
    if (budgets.isEmpty) {
      return EmptyState(
        key: const ValueKey('empty'),
        icon: Icons.account_balance_wallet_rounded,
        title: 'No budgets yet',
        message:
            'A budget has its own amount and dates. Create one to start '
            'tracking your spending.',
        actionLabel: 'Create budget',
        actionIcon: Icons.add_rounded,
        onAction: () => context.pushUnique('/app/budgets/create'),
      );
    }

    final now = BudgetListScreen.clock();
    BudgetEntity? active;
    final groups = <BudgetPhase, List<BudgetEntity>>{};
    for (final b in budgets) {
      if (b.id == _activeBudgetId) {
        active = b;
        continue;
      }
      groups.putIfAbsent(b.phaseOn(now), () => []).add(b);
    }
    for (final list in groups.values) {
      list.sort((a, b) => a.startDate.compareTo(b.startDate));
    }

    const order = [
      (BudgetPhase.running, 'Running today', null),
      (BudgetPhase.upcoming, 'Starting later', null),
      (BudgetPhase.ended, 'Ended', 'Create a new budget to keep tracking'),
      (BudgetPhase.archived, 'Archived', null),
    ];

    var index = 0;
    return RefreshIndicator(
      key: const ValueKey('list'),
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.pagePaddingWithFab,
        children: [
          // The active budget is the one raised surface.
          if (active != null) ...[
            FadeSlideIn(
              index: index++,
              child: ActiveBudgetCard(
                budget: active,
                now: now,
                onTap: () => context.pushUnique('/app/budgets/${active!.id}'),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          for (final (phase, title, subtitle) in order)
            if (groups[phase] case final list? when list.isNotEmpty) ...[
              FadeSlideIn(
                index: index++,
                child: AppSection(
                  title: active != null && phase == BudgetPhase.running
                      ? 'Also running today'
                      : title,
                  subtitle: subtitle,
                  child: AppGroupedList(
                    dividerIndent: AppSizes.avatarSm + AppSpacing.smd,
                    children: [
                      for (final budget in list)
                        BudgetRow(
                          budget: budget,
                          now: now,
                          onTap: () =>
                              context.pushUnique('/app/budgets/${budget.id}'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          // Last and quiet: a reference figure, never a pooled budget.
          if (_summary != null && _summary!.activeBudgetCount > 0)
            BudgetListSummaryCard(summary: _summary!),
        ],
      ),
    );
  }
}
