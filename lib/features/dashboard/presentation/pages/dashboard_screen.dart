import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/navigation/push_unique.dart';
import '../../../../core/widgets/app_fab.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_list.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/delayed_reveal.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_status.dart';
import '../../../budget/presentation/widgets/active_budget_selector.dart';
import '../../domain/entities/budget_daily_limit_entity.dart';
import '../../domain/entities/recent_expense_entity.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../widgets/dashboard_header.dart';
import '../../../expenses/presentation/quick_add/quick_add_sheet.dart';
import '../widgets/free_to_spend_summary.dart';
import '../widgets/home_insights.dart';
import '../widgets/link_bills_sheet.dart';
import '../widgets/recent_expense_tile.dart';
import '../widgets/safe_spending_hero.dart';
import '../widgets/safe_to_spend_breakdown_card.dart';
import '../widgets/safe_to_spend_notices.dart';
import '../widgets/spending_pace_section.dart';
import '../widgets/upcoming_bills_section.dart';

/// Home: what can I spend today, how is the budget doing, and what should I
/// know or do next.
///
/// Reading order, top to bottom: the budget and greeting; Today's Safe
/// Spending (the one raised surface); what is free to spend, with the full
/// working one tap away; anything today's amount leaves out; bills coming
/// up; the spending pace; insights the rest of the screen does not already
/// say; other budgets running today; recent expenses. Sections sit on the
/// page, separated by space and type rather than borders.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  /// The button keeps its label at rest and folds to its icon while the
  /// user scrolls down, so it covers less of the amounts on the right.
  bool _fabExtended = true;

  /// Whether [state] shows a dashboard the FAB belongs on.
  static bool _hasContent(DashboardState state) =>
      state is DashboardLoaded || state is DashboardNotRunning;

  bool _onScroll(UserScrollNotification notification) {
    final extended = switch (notification.direction) {
      ScrollDirection.reverse => false,
      ScrollDirection.forward => true,
      ScrollDirection.idle => _fabExtended,
    };
    if (extended != _fabExtended) setState(() => _fabExtended = extended);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: NotificationListener<UserScrollNotification>(
          onNotification: _onScroll,
          child: BlocBuilder<DashboardBloc, DashboardState>(
            // DashboardBloc re-emits on every expense, budget and bill change
            // from any tab. Equatable states mean an unchanged refresh is a
            // no-op here rather than a full-page rebuild.
            buildWhen: (prev, curr) => prev != curr,
            builder: (context, state) {
              final child = switch (state) {
                DashboardInitial() || DashboardLoading() => const DelayedReveal(
                  key: ValueKey('loading'),
                  child: DashboardSkeleton(),
                ),
                DashboardLoaded() => _DashboardContent(
                  key: const ValueKey('loaded'),
                  state: state,
                ),
                DashboardNotRunning() => _NotRunningContent(
                  key: const ValueKey('not_running'),
                  state: state,
                ),
                DashboardEmpty() => const _NoBudgetState(
                  key: ValueKey('empty'),
                ),
                DashboardError(:final message) => _DashboardError(
                  key: const ValueKey('error'),
                  details: message,
                ),
                _ => const SizedBox.shrink(key: ValueKey('unknown')),
              };
              return AppStateSwitcher(child: child);
            },
          ),
        ),
      ),
      floatingActionButton: BlocBuilder<DashboardBloc, DashboardState>(
        buildWhen: (a, b) => _hasContent(a) != _hasContent(b),
        builder: (context, state) {
          if (!_hasContent(state)) return const SizedBox.shrink();
          return AppFab(
            heroTag: 'dashboard_fab',
            onPressed: () => QuickAddSheet.show(context),
            icon: Icons.add_rounded,
            label: 'Add expense',
            tooltip: 'Add expense',
            extended: _fabExtended,
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

/// Space between top-level sections. Sections are told apart by this and
/// by their titles, not by borders.
const double _sectionGap = AppSpacing.xl;

// ── Loaded content ─────────────────────────────────────────────────────────

class _DashboardContent extends StatelessWidget {
  final DashboardLoaded state;

  const _DashboardContent({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final activeLimit = state.activeBudgetLimit;
    final safeToSpend = state.activeSafeToSpend;
    final pace = state.spendingPace;
    final insights = HomeInsightFilter.visible(state.insights);

    return _DashboardScroll(
      children: [
        FadeSlideIn(index: 0, child: _header(context, safeToSpend)),
        const SizedBox(height: AppSpacing.md),

        // Today's Safe Spending: the one raised surface.
        FadeSlideIn(
          index: 1,
          child: SafeSpendingHeroSwitcher(
            // Keyed by budget: switching budgets cross-fades, refreshing the
            // same budget animates values in place.
            child: activeLimit != null
                ? SafeSpendingHero(
                    key: ValueKey('hero_${activeLimit.budgetId}'),
                    limit: activeLimit,
                    onShowWorking: safeToSpend == null
                        ? null
                        : () => SafeToSpendWorkingSheet.show(
                            context,
                            safeToSpend,
                          ),
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

        // What is free to spend (the working one tap away), then anything
        // today's amount leaves out.
        if (safeToSpend != null) ...[
          const SizedBox(height: AppSpacing.sm),
          FadeSlideIn(
            index: 2,
            child: FreeToSpendSummary(
              key: ValueKey('free_to_spend_${safeToSpend.budgetId}'),
              safeToSpend: safeToSpend,
              onTap: () => SafeToSpendWorkingSheet.show(context, safeToSpend),
            ),
          ),
          ..._notices(context, safeToSpend, index: 2),
        ],

        const SizedBox(height: _sectionGap),
        FadeSlideIn(
          index: 3,
          child: UpcomingBillsSection(
            bills: state.upcomingBills,
            activeBudgetId: state.activeBudgetId,
            budgetNames: {
              for (final limit in state.budgetDailyLimits)
                limit.budgetId: limit.budgetName,
            },
          ),
        ),

        if (pace != null && pace.isMeaningful) ...[
          const SizedBox(height: _sectionGap),
          FadeSlideIn(index: 4, child: SpendingPaceSection(pace: pace)),
        ],

        if (insights.isNotEmpty) ...[
          const SizedBox(height: _sectionGap),
          FadeSlideIn(index: 4, child: HomeInsightsSection(insights: insights)),
        ],

        ..._otherBudgets(state.otherBudgetLimits),

        ..._recentExpenses(
          context,
          state.recentExpenses,
          state.budgetSummary.currency,
          today: safeToSpend?.today,
        ),
      ],
    );
  }

  Widget _header(BuildContext context, SafeToSpendEntity? safeToSpend) {
    if (safeToSpend == null) {
      // No engine result (archived, or figures unavailable) means no budget
      // name in this state; the selector reads it on its own.
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardHeader(),
          SizedBox(height: AppSpacing.sm),
          ActiveBudgetSelector(),
        ],
      );
    }
    return DashboardHeader(
      budgetName: safeToSpend.budgetName,
      caption: formatDateRange(safeToSpend.startDate, safeToSpend.endDate),
      onSwitchBudget: () => ActiveBudgetSelector.open(context),
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
        FadeSlideIn(
          index: 0,
          child: DashboardHeader(
            budgetName: safeToSpend.budgetName,
            caption: formatDateRange(
              safeToSpend.startDate,
              safeToSpend.endDate,
            ),
            onSwitchBudget: () => ActiveBudgetSelector.open(context),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FadeSlideIn(
          index: 1,
          child: SafeSpendingHeroSwitcher(
            child: SafeSpendingNotRunningCard(
              key: ValueKey('paused_${state.activeBudgetId}'),
              safeToSpend: safeToSpend,
              onSwitch: () => ActiveBudgetSelector.open(context),
            ),
          ),
        ),
        // Before the period starts: what it will set aside.
        if (safeToSpend.status == SafeToSpendStatus.notStarted) ...[
          const SizedBox(height: AppSpacing.sm),
          FadeSlideIn(
            index: 2,
            child: AppSurface(
              level: SurfaceLevel.sunken,
              child: SafeToSpendBreakdownCard(
                key: ValueKey('breakdown_${safeToSpend.budgetId}'),
                safeToSpend: safeToSpend,
              ),
            ),
          ),
          ..._notices(context, safeToSpend, index: 2),
        ],
        const SizedBox(height: _sectionGap),
        FadeSlideIn(
          index: 3,
          child: UpcomingBillsSection(
            bills: state.upcomingBills,
            activeBudgetId: state.activeBudgetId,
            budgetNames: {
              for (final limit in state.otherBudgetLimits)
                limit.budgetId: limit.budgetName,
              state.activeBudgetId: safeToSpend.budgetName,
            },
          ),
        ),
        ..._otherBudgets(state.otherBudgetLimits),
        ..._recentExpenses(
          context,
          state.recentExpenses,
          safeToSpend.currency,
          today: safeToSpend.today,
        ),
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

/// Notices for anything today's amount leaves out (bills unavailable, not
/// linked, or in another currency); nothing when everything is included.
List<Widget> _notices(
  BuildContext context,
  SafeToSpendEntity safeToSpend, {
  required int index,
}) => [
  if (SafeToSpendNotices.hasNotices(safeToSpend)) ...[
    const SizedBox(height: AppSpacing.sm),
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
    const SizedBox(height: _sectionGap),
    FadeSlideIn(
      index: 5,
      child: AppSection(
        title: 'Other budgets today',
        subtitle: 'Each budget has its own safe amount',
        child: AppGroupedList(
          dividerIndent: AppSizes.avatarSm + AppSpacing.smd,
          children: [
            for (final limit in others)
              OtherBudgetLimitTile(
                key: ValueKey('other_${limit.budgetId}'),
                limit: limit,
              ),
          ],
        ),
      ),
    ),
  ],
];

List<Widget> _recentExpenses(
  BuildContext context,
  List<RecentExpenseEntity> expenses,
  String currency, {
  DateTime? today,
}) {
  final theme = Theme.of(context);
  return [
    const SizedBox(height: _sectionGap),
    FadeSlideIn(
      index: 6,
      child: AppSection(
        title: 'Recent',
        action: expenses.isEmpty
            ? null
            : TextButton(
                onPressed: () => context.go('/app/expenses'),
                child: const Text('See all'),
              ),
        child: expenses.isEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No expenses yet', style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    "Add your first expense and today's spending will "
                    'update here.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.tonalIcon(
                    onPressed: () => QuickAddSheet.show(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add expense'),
                  ),
                ],
              )
            : AppGroupedList(
                dividerIndent: AppSizes.avatarSm + AppSpacing.smd,
                children: [
                  for (final expense in expenses)
                    RecentExpenseTile(
                      key: ValueKey('recent_${expense.id}'),
                      expense: expense,
                      currency: currency,
                      today: today,
                      onTap: () =>
                          context.pushUnique('/app/expenses/${expense.id}'),
                    ),
                ],
              ),
      ),
    ),
  ];
}

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

/// A calm failure: what happened and what to do, with the technical detail
/// behind a disclosure for anyone reporting a problem.
class _DashboardError extends StatefulWidget {
  final String details;

  const _DashboardError({super.key, required this.details});

  @override
  State<_DashboardError> createState() => _DashboardErrorState();
}

class _DashboardErrorState extends State<_DashboardError> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xxl),
          ErrorState(
            title: "Couldn't load your dashboard",
            message:
                'Your budgets and expenses are still on this device. '
                'Try again in a moment.',
            onRetry: () => _refresh(context),
          ),
          TextButton(
            onPressed: () => setState(() => _showDetails = !_showDetails),
            child: Text(_showDetails ? 'Hide details' : 'Show details'),
          ),
          if (_showDetails)
            SelectableText(
              widget.details,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
