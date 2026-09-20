import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../expenses/presentation/bloc/expense_refresh_bus.dart';
import '../../domain/entities/budget_error.dart';
import '../../domain/entities/budget_list_summary_entity.dart';
import '../../domain/usecases/get_budget_list_summary_usecase.dart';
import '../../domain/usecases/manage_budget_usecase.dart';
import '../bloc/budget_bloc.dart';
import '../widgets/budget_card.dart';
import '../widgets/budget_list_summary_card.dart';
import '../widgets/budget_visuals.dart';
import '../../../../core/widgets/app_fab.dart';

/// Lists all budgets, grouped by where they are in their lifecycle, with the
/// active budget marked. Each budget stays independent.
class BudgetListScreen extends StatefulWidget {
  const BudgetListScreen({super.key});

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
    _refreshSubscription = ExpenseRefreshBus.instance.changes.listen((_) {
      if (mounted) _load(silent: true);
    });
    _budgetSwitchSubscription = BudgetRefreshBus.instance.changes.listen((_) {
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
        _error = "Couldn't load your budgets.";
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
        onPressed: () => context.push('/app/budgets/create'),
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
        onAction: () => context.push('/app/budgets/create'),
      );
    }

    final now = DateTime.now();
    final groups = <BudgetPhase, List<BudgetEntity>>{};
    for (final b in budgets) {
      groups.putIfAbsent(b.phaseOn(now), () => []).add(b);
    }
    // Active budget first within its group.
    for (final list in groups.values) {
      list.sort((a, b) {
        if (a.id == _activeBudgetId) return -1;
        if (b.id == _activeBudgetId) return 1;
        return a.startDate.compareTo(b.startDate);
      });
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
          if (_summary != null && _summary!.activeBudgetCount > 0) ...[
            FadeSlideIn(
              index: index++,
              child: BudgetListSummaryCard(summary: _summary!),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          for (final (phase, title, subtitle) in order)
            if (groups[phase] case final list? when list.isNotEmpty) ...[
              SectionHeader(title: title, subtitle: subtitle),
              for (final budget in list)
                // Keyed by id: switching the active budget re-sorts the
                // list without replaying entrances.
                FadeSlideIn(
                  key: ValueKey('budget_${budget.id}'),
                  index: index++,
                  child: BudgetCard(
                    budget: budget,
                    isActive: budget.id == _activeBudgetId,
                    onTap: () => context.push('/app/budgets/${budget.id}'),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),
    );
  }
}
