import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../bills/domain/entities/bill_entity.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_status.dart';
import '../../../budget/presentation/widgets/active_budget_selector.dart';
import '../../domain/entities/budget_daily_limit_entity.dart';
import '../../domain/entities/recent_expense_entity.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../widgets/budget_overview_card.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_info.dart';
import '../widgets/insight_card.dart';
import '../widgets/quick_actions.dart';
import '../widgets/recent_expense_tile.dart';
import '../widgets/link_bills_sheet.dart';
import '../widgets/safe_spending_hero.dart';
import '../widgets/safe_to_spend_breakdown_card.dart';
import '../widgets/safe_to_spend_notices.dart';
import '../widgets/upcoming_bills_section.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/widgets/app_fab.dart';
import '../../../../core/navigation/push_unique.dart';

/// Home tab: the financial overview for the active budget.
///
/// Reading order answers, top to bottom: what can I safely spend today, how
/// is that figure made up (bills, money kept aside, savings goal) and where
/// is it heading, what isn't included, how much remains, what should I
/// know, what happened recently, what's due soon.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  /// Whether [state] shows a dashboard the FAB belongs on.
  static bool _hasContent(DashboardState state) =>
      state is DashboardLoaded || state is DashboardNotRunning;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<DashboardBloc, DashboardState>(
          // DashboardBloc re-emits on every expense, budget and bill change
          // from any tab. Equatable states mean an unchanged refresh is a
          // no-op here rather than a full-page rebuild.
          buildWhen: (prev, curr) => prev != curr,
          builder: (context, state) {
            final child = switch (state) {
              DashboardInitial() || DashboardLoading() =>
                const DashboardSkeleton(key: ValueKey('loading')),
              DashboardLoaded() => _DashboardContent(
                key: const ValueKey('loaded'),
                state: state,
              ),
              DashboardNotRunning() => _NotRunningContent(
                key: const ValueKey('not_running'),
                state: state,
              ),
              DashboardEmpty() => _NoBudgetState(key: const ValueKey('empty')),
              DashboardError(:final message) => _DashboardError(
                key: const ValueKey('error'),
                message: message,
              ),
              _ => const SizedBox.shrink(key: ValueKey('unknown')),
            };
            return AppStateSwitcher(child: child);
          },
        ),
      ),
      floatingActionButton: BlocBuilder<DashboardBloc, DashboardState>(
        buildWhen: (a, b) => _hasContent(a) != _hasContent(b),
        builder: (context, state) {
          if (!_hasContent(state)) return const SizedBox.shrink();
          return AppFab(
            heroTag: 'dashboard_fab',
            onPressed: () => context.pushUnique('/app/expenses/add'),
            icon: Icons.add_rounded,
            label: 'Add expense',
            tooltip: 'Add expense',
            // Appears once the dashboard has loaded; the Scaffold animates
            // it in.
            animateEntrance: false,
          );
        },
      ),
    );
  }
}

void _refresh(BuildContext context) =>
    context.read<DashboardBloc>().add(const DashboardRefresh());

// ── Loaded content ─────────────────────────────────────────────────────────

class _DashboardContent extends StatelessWidget {
  final DashboardLoaded state;

  const _DashboardContent({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final summary = state.budgetSummary;
    final activeLimit = state.activeBudgetLimit;
    final safeToSpend = state.activeSafeToSpend;

    return _DashboardScroll(
      children: [
        // 1. Greeting + active budget context
        const FadeSlideIn(index: 0, child: DashboardHeader()),
        const SizedBox(height: AppSpacing.smd),
        const FadeSlideIn(index: 1, child: ActiveBudgetSelector()),
        const SizedBox(height: AppSpacing.md),

        // 2. Today's Safe Spending (hero)
        FadeSlideIn(
          index: 2,
          child: SafeSpendingHeroSwitcher(
            // Keyed by budget: switching budgets cross-fades, refreshing the
            // same budget animates values in place.
            child: activeLimit != null
                ? SafeSpendingHero(
                    key: ValueKey('hero_${activeLimit.budgetId}'),
                    limit: activeLimit,
                  )
                // Archived budgets get no daily figure: a retry can't help.
                : state.activeBudgetArchived
                ? SafeSpendingArchivedCard(
                    key: ValueKey('archived_${state.activeBudgetId}'),
                    onSwitch: () => ActiveBudgetSelector.open(context),
                    onOpenBudget: state.activeBudgetId == null
                        ? null
                        : () => context.pushUnique(
                            '/app/budgets/${state.activeBudgetId}',
                          ),
                  )
                // Running (the summary loaded) but its figures could not be
                // computed: say so rather than claiming the period ended.
                : SafeSpendingUnavailableCard(
                    key: ValueKey('paused_${state.activeBudgetId}'),
                    onRetry: () => _refresh(context),
                    onSwitch: () => ActiveBudgetSelector.open(context),
                  ),
          ),
        ),

        // 3. How the amount is made up, and the forecast; then what it
        //    leaves out.
        if (safeToSpend != null)
          ..._safeToSpendDetails(context, safeToSpend, index: 3),
        const SizedBox(height: AppSpacing.smd),

        // 4. Budget progress / remaining / timeline
        FadeSlideIn(
          index: 4,
          child: BudgetOverviewCard(
            summary: summary,
            onTap: state.activeBudgetId == null
                ? null
                : () => context.pushUnique(
                    '/app/budgets/${state.activeBudgetId}',
                  ),
          ),
        ),

        // 4b. Other budgets running today (independent amounts)
        ..._otherBudgets(state.otherBudgetLimits),

        // 5. Smart insights
        if (state.insights.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(
            title: 'Smart insights',
            infoContent: DashboardInfo.smartInsights,
          ),
          // Keyed by insight so a changed set never hands one insight's
          // element (and finished entrance) to another.
          for (var i = 0; i < state.insights.length; i++)
            FadeSlideIn(
              key: ValueKey('insight_${state.insights[i].id}'),
              index: 5 + i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: InsightCard(
                  message: state.insights[i].message,
                  type: state.insights[i].type,
                ),
              ),
            ),
        ],

        // 6. Recent transactions
        ..._recentExpenses(context, state.recentExpenses, summary.currency),

        // 7. Upcoming bills + quick actions
        ..._footer(state.upcomingBills),
      ],
    );
  }
}

// ── Active budget not running today ────────────────────────────────────────

/// The active budget has not started or has ended: the engine's result for
/// it in place of the hero (and, before it starts, what it will set aside),
/// next to the budgets that are running today.
class _NotRunningContent extends StatelessWidget {
  final DashboardNotRunning state;

  const _NotRunningContent({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final safeToSpend = state.safeToSpend;
    return _DashboardScroll(
      children: [
        const FadeSlideIn(index: 0, child: DashboardHeader()),
        const SizedBox(height: AppSpacing.smd),
        const FadeSlideIn(index: 1, child: ActiveBudgetSelector()),
        const SizedBox(height: AppSpacing.md),
        FadeSlideIn(
          index: 2,
          child: SafeSpendingHeroSwitcher(
            child: SafeSpendingNotRunningCard(
              key: ValueKey('paused_${state.activeBudgetId}'),
              safeToSpend: safeToSpend,
              onSwitch: () => ActiveBudgetSelector.open(context),
            ),
          ),
        ),
        if (safeToSpend.status == SafeToSpendStatus.notStarted)
          ..._safeToSpendDetails(context, safeToSpend, index: 3),
        ..._otherBudgets(state.otherBudgetLimits),
        ..._recentExpenses(context, state.recentExpenses, safeToSpend.currency),
        ..._footer(state.upcomingBills),
      ],
    );
  }
}

// ── Shared sections ────────────────────────────────────────────────────────

/// Pull-to-refresh scroll view with the dashboard's width constraint.
class _DashboardScroll extends StatelessWidget {
  final List<Widget> children;

  const _DashboardScroll({required this.children});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () {
        // Resolves when the reload finishes, even when nothing changed (an
        // unchanged Equatable state is never re-emitted, so the stream
        // alone could not tell us).
        final completion = Completer<void>();
        context.read<DashboardBloc>().add(
          DashboardRefresh(completion: completion),
        );
        return completion.future;
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.pagePaddingWithFab,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "Free to spend" breakdown with its forecast, then a notice for
/// anything today's amount leaves out (bills unavailable, not linked, or in
/// another currency).
List<Widget> _safeToSpendDetails(
  BuildContext context,
  SafeToSpendEntity safeToSpend, {
  required int index,
}) => [
  const SizedBox(height: AppSpacing.smd),
  FadeSlideIn(
    index: index,
    child: SafeToSpendBreakdownCard(
      // Per budget, so a switch starts with the bills list collapsed.
      key: ValueKey('breakdown_${safeToSpend.budgetId}'),
      safeToSpend: safeToSpend,
    ),
  ),
  if (SafeToSpendNotices.hasNotices(safeToSpend)) ...[
    const SizedBox(height: AppSpacing.smd),
    FadeSlideIn(
      index: index,
      child: SafeToSpendNotices(
        safeToSpend: safeToSpend,
        onLinkBills: () =>
            LinkBillsSheet.open(context, budgetId: safeToSpend.budgetId),
        onRetry: () => _refresh(context),
      ),
    ),
  ],
];

List<Widget> _otherBudgets(List<BudgetDailyLimitEntity> others) => [
  if (others.isNotEmpty) ...[
    const SizedBox(height: AppSpacing.lg),
    const SectionHeader(
      title: 'Other budgets today',
      subtitle: 'Each budget has its own safe amount',
    ),
    for (var i = 0; i < others.length; i++)
      FadeSlideIn(
        key: ValueKey('other_${others[i].budgetId}'),
        index: 5 + i,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: OtherBudgetLimitTile(limit: others[i]),
        ),
      ),
  ],
];

List<Widget> _recentExpenses(
  BuildContext context,
  List<RecentExpenseEntity> expenses,
  String currency,
) {
  final theme = Theme.of(context);
  return [
    const SizedBox(height: AppSpacing.lg),
    SectionHeader(
      title: 'Recent expenses',
      trailing: expenses.isEmpty
          ? null
          : TextButton(
              onPressed: () => context.go('/app/expenses'),
              child: const Text('View all'),
            ),
    ),
    if (expenses.isEmpty)
      EmptyState.compact(
        icon: Icons.receipt_long_rounded,
        title: 'No expenses yet',
        message:
            'Add your first expense and today\'s spending '
            'will update here.',
        actionLabel: 'Add expense',
        actionIcon: Icons.add_rounded,
        onAction: () => context.pushUnique('/app/expenses/add'),
      )
    else
      // The card grows smoothly when a new expense arrives; rows are keyed
      // by id so only the new one slides in.
      AnimatedSize(
        duration: AppMotion.respectReducedMotion(context, AppMotion.medium),
        curve: AppMotion.standardCurve,
        alignment: Alignment.topCenter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: AppSpacing.borderRadiusLg,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                for (var i = 0; i < expenses.length; i++) ...[
                  if (i > 0)
                    Divider(
                      key: ValueKey('recent_div_${expenses[i].id}'),
                      indent: AppSizes.avatarMd + AppSpacing.mlg,
                      color: theme.colorScheme.outlineVariant,
                    ),
                  FadeSlideIn(
                    key: ValueKey('recent_${expenses[i].id}'),
                    // Relative to the card, so a newly added expense appears
                    // as its slot opens rather than leaving a gap first.
                    index: i,
                    child: RecentExpenseTile(
                      expense: expenses[i],
                      currency: currency,
                      onTap: () =>
                          context.pushUnique('/app/expenses/${expenses[i].id}'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
  ];
}

List<Widget> _footer(List<BillEntity> upcomingBills) => [
  // Upcoming bills
  const SizedBox(height: AppSpacing.lg),
  FadeSlideIn(index: 6, child: UpcomingBillsSection(bills: upcomingBills)),

  // Quick actions
  const SizedBox(height: AppSpacing.lg),
  const FadeSlideIn(index: 7, child: SectionHeader(title: 'Quick actions')),
  const FadeSlideIn(index: 7, child: QuickActions()),
];

// ── Empty / error ──────────────────────────────────────────────────────────

class _NoBudgetState extends StatelessWidget {
  const _NoBudgetState({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Create your first budget',
      message:
          'A budget gives you a daily safe-spending amount and keeps every '
          'expense in context.',
      actionLabel: 'Create budget',
      actionIcon: Icons.add_rounded,
      onAction: () async {
        await context.pushUnique('/app/budgets/create');
        if (context.mounted) {
          context.read<DashboardBloc>().add(const DashboardRefresh());
        }
      },
      secondaryActionLabel: 'Open Budgets',
      onSecondaryAction: () => context.pushUnique('/app/budgets'),
    );
  }
}

class _DashboardError extends StatelessWidget {
  final String message;

  const _DashboardError({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return ErrorState(
      title: "Couldn't load your dashboard",
      message: message,
      onRetry: () => _refresh(context),
    );
  }
}
