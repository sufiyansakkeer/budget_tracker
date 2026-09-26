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
import '../../../budget/presentation/widgets/active_budget_selector.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../widgets/budget_overview_card.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_info.dart';
import '../widgets/insight_card.dart';
import '../widgets/quick_actions.dart';
import '../widgets/recent_expense_tile.dart';
import '../widgets/safe_spending_hero.dart';
import '../widgets/upcoming_bills_section.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/widgets/app_fab.dart';
import '../../../../core/navigation/push_unique.dart';

/// Home tab: the financial overview for the active budget.
///
/// Reading order answers, top to bottom: what can I safely spend today, how
/// much have I spent, am I on track, how much remains, what should I know,
/// what happened recently, what's due soon.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
        buildWhen: (a, b) => (a is DashboardLoaded) != (b is DashboardLoaded),
        builder: (context, state) {
          if (state is! DashboardLoaded) return const SizedBox.shrink();
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

// ── Loaded content ─────────────────────────────────────────────────────────

class _DashboardContent extends StatelessWidget {
  final DashboardLoaded state;

  const _DashboardContent({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final summary = state.budgetSummary;
    final activeLimit = state.activeBudgetLimit;
    final others = state.otherBudgetLimits;
    final theme = Theme.of(context);

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
                      // Keyed by budget: switching budgets cross-fades,
                      // refreshing the same budget animates values in place.
                      child: activeLimit != null
                          ? SafeSpendingHero(
                              key: ValueKey('hero_${activeLimit.budgetId}'),
                              limit: activeLimit,
                            )
                          : BudgetNotRunningCard(
                              key: ValueKey('paused_${state.activeBudgetId}'),
                              startDate: summary.startDate,
                              endDate: summary.endDate,
                              onSwitch: () =>
                                  ActiveBudgetSelector.open(context),
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.smd),

                  // 3. Budget progress / remaining / timeline
                  FadeSlideIn(
                    index: 3,
                    child: BudgetOverviewCard(
                      summary: summary,
                      onTap: state.activeBudgetId == null
                          ? null
                          : () => context.pushUnique(
                              '/app/budgets/${state.activeBudgetId}',
                            ),
                    ),
                  ),

                  // 3b. Other budgets running today (independent amounts)
                  if (others.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    SectionHeader(
                      title: 'Other budgets today',
                      subtitle: 'Each budget has its own safe amount',
                    ),
                    for (var i = 0; i < others.length; i++)
                      FadeSlideIn(
                        key: ValueKey('other_${others[i].budgetId}'),
                        index: 4 + i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: OtherBudgetLimitTile(limit: others[i]),
                        ),
                      ),
                  ],

                  // 4. Smart insights
                  if (state.insights.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const SectionHeader(
                      title: 'Smart insights',
                      infoContent: DashboardInfo.smartInsights,
                    ),
                    // Keyed by insight so a changed set never hands one
                    // insight's element (and finished entrance) to another.
                    for (var i = 0; i < state.insights.length; i++)
                      FadeSlideIn(
                        key: ValueKey('insight_${state.insights[i].id}'),
                        index: 4 + i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: InsightCard(
                            message: state.insights[i].message,
                            type: state.insights[i].type,
                          ),
                        ),
                      ),
                  ],

                  // 5. Recent transactions
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(
                    title: 'Recent expenses',
                    trailing: state.recentExpenses.isEmpty
                        ? null
                        : TextButton(
                            onPressed: () => context.go('/app/expenses'),
                            child: const Text('View all'),
                          ),
                  ),
                  if (state.recentExpenses.isEmpty)
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
                    // The card grows smoothly when a new expense arrives;
                    // rows are keyed by id so only the new one slides in.
                    AnimatedSize(
                      duration: AppMotion.respectReducedMotion(
                        context,
                        AppMotion.medium,
                      ),
                      curve: AppMotion.standardCurve,
                      alignment: Alignment.topCenter,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color,
                          borderRadius: AppSpacing.borderRadiusLg,
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          child: Column(
                            children: [
                              for (
                                var i = 0;
                                i < state.recentExpenses.length;
                                i++
                              ) ...[
                                if (i > 0)
                                  Divider(
                                    key: ValueKey(
                                      'recent_div_${state.recentExpenses[i].id}',
                                    ),
                                    indent: AppSizes.avatarMd + AppSpacing.mlg,
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                FadeSlideIn(
                                  key: ValueKey(
                                    'recent_${state.recentExpenses[i].id}',
                                  ),
                                  // Relative to the card, so a newly added
                                  // expense appears as its slot opens rather
                                  // than leaving a gap first.
                                  index: i,
                                  child: RecentExpenseTile(
                                    expense: state.recentExpenses[i],
                                    currency: summary.currency,
                                    onTap: () => context.pushUnique(
                                      '/app/expenses/${state.recentExpenses[i].id}',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                  // 6. Upcoming bills
                  const SizedBox(height: AppSpacing.lg),
                  FadeSlideIn(
                    index: 6,
                    child: UpcomingBillsSection(bills: state.upcomingBills),
                  ),

                  // 7. Quick actions
                  const SizedBox(height: AppSpacing.lg),
                  const FadeSlideIn(
                    index: 7,
                    child: SectionHeader(title: 'Quick actions'),
                  ),
                  const FadeSlideIn(index: 7, child: QuickActions()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
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

class _DashboardError extends StatelessWidget {
  final String message;

  const _DashboardError({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return ErrorState(
      title: "Couldn't load your dashboard",
      message: message,
      onRetry: () =>
          context.read<DashboardBloc>().add(const DashboardRefresh()),
    );
  }
}
