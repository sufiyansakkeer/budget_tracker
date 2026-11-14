import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/navigation/push_unique.dart';
import '../../../../core/dates/date_range_format.dart';
import '../../../../core/widgets/app_list.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_status.dart';
import '../../../budget/presentation/widgets/active_budget_selector.dart';
import '../../../pay_later/presentation/widgets/pay_later_home_row.dart';
import '../../domain/entities/budget_daily_limit_entity.dart';
import '../../domain/entities/recent_expense_entity.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../widgets/dashboard_header.dart';
import '../../../expenses/presentation/quick_add/quick_add_sheet.dart';
import '../widgets/link_bills_sheet.dart';
import '../widgets/recent_expense_tile.dart';
import '../widgets/budget_chips.dart';
import '../widgets/safe_spending_hero.dart';
import '../widgets/free_to_spend_summary.dart';
import '../widgets/target_ring.dart';
import '../widgets/tomorrow_card.dart';
import '../widgets/why_target_row.dart';
import '../widgets/safe_to_spend_breakdown_card.dart';
import '../widgets/safe_to_spend_notices.dart';
import '../widgets/notification_priming_card.dart';
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
  /// Opened from the home-screen widget's "Add expense": quick add opens
  /// over Home once, when it first shows.
  final bool openQuickAdd;

  const DashboardScreen({super.key, this.openQuickAdd = false});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.openQuickAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) QuickAddSheet.show(context);
      });
    }
  }

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
              DashboardEmpty() => const _NoBudgetState(key: ValueKey('empty')),
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
      // Adding is the bar's + (AppShell).
    );
  }
}

void _refresh(BuildContext context) =>
    context.read<DashboardBloc>().add(const DashboardRefresh());

/// Home's entrance stagger: a short cascade, so the figures settle soon
/// after the skeleton fades (review: 7 steps settled at about 590 ms). The
/// header and Today's Safe Spending arrive together; everything below the
/// bills shares the last step.
abstract final class _Stagger {
  static const int top = 0;
  static const int summary = 1;
  static const int bills = 2;
  static const int rest = 3;
}

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
    final todays = safeToSpend == null
        ? const <RecentExpenseEntity>[]
        : _todays(state.recentExpenses, safeToSpend.today);

    // Blueprint order: the date and the budgets running today, the ring,
    // tomorrow's target; then today's expenses, why the target is what it
    // is, and what is coming that changes it.
    return _DashboardScroll(
      primary: [
        FadeSlideIn(index: _Stagger.top, child: _header(context, safeToSpend)),
        const SizedBox(height: AppSpacing.sm),
        FadeSlideIn(
          index: _Stagger.top,
          child: SafeSpendingHeroSwitcher(
            // Keyed by budget: switching budgets cross-fades, refreshing the
            // same budget animates values in place.
            child: activeLimit != null
                ? SafeSpendingHero(
                    key: ValueKey('hero_${activeLimit.budgetId}'),
                    limit: activeLimit,
                    // Oldest first: the ring's arcs go round in time order.
                    segments: [for (final e in todays.reversed) e.amount],
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
        if (safeToSpend != null) ...[
          const SizedBox(height: AppSpacing.lg),
          FadeSlideIn(
            index: _Stagger.summary,
            child: TomorrowCard(safeToSpend: safeToSpend),
          ),
        ],
      ],
      secondary: [
        ..._recentExpenses(
          context,
          state.recentExpenses,
          state.budgetSummary.currency,
          today: safeToSpend?.today,
          todayOnly: safeToSpend != null,
        ),
        if (safeToSpend != null) ...[
          FadeSlideIn(
            index: _Stagger.rest,
            child: WhyTargetRow(
              safeToSpend: safeToSpend,
              onTap: () => SafeToSpendWorkingSheet.show(context, safeToSpend),
            ),
          ),
          ..._notices(context, safeToSpend, index: _Stagger.rest),
        ],
        const SizedBox(height: _sectionGap),
        FadeSlideIn(
          index: _Stagger.bills,
          child: UpcomingBillsSection(
            bills: state.upcomingBills,
            unavailable: state.upcomingBillsUnavailable,
            hasBills: state.hasBills,
            onRetry: () =>
                context.read<DashboardBloc>().add(const DashboardRefresh()),
            activeBudgetId: state.activeBudgetId,
            activeSafeToSpend: safeToSpend,
            setAsideBillIds: {
              for (final o in state.activeSafeToSpend?.commitments ?? const [])
                o.billId,
            },
            budgetNames: {
              for (final limit in state.budgetDailyLimits)
                limit.budgetId: limit.budgetName,
            },
          ),
        ),
        const PayLaterHomeRow(),
        const NotificationPrimingCard(),
      ],
    );
  }

  /// [all] dated [day], newest first (as the recent list comes).
  static List<RecentExpenseEntity> _todays(
    List<RecentExpenseEntity> all,
    DateTime day,
  ) => [
    for (final e in all)
      if (e.date.year == day.year &&
          e.date.month == day.month &&
          e.date.day == day.day)
        e,
  ];

  /// The date and the day of the period, then the budgets running today as
  /// chips (blueprint); the chips are the screen's title and switcher.
  Widget _header(BuildContext context, SafeToSpendEntity? safeToSpend) {
    final theme = Theme.of(context);
    if (state.budgetDailyLimits.isEmpty || safeToSpend == null) {
      // No engine result (archived, or figures unavailable): the selector
      // reads the budget on its own.
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardHeader(),
          SizedBox(height: AppSpacing.sm),
          ActiveBudgetSelector(),
        ],
      );
    }
    final date = DateFormat('EEEE d MMMM').format(safeToSpend.today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$date · day ${safeToSpend.daysPassed} of ${safeToSpend.totalDays}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        BudgetChips(
          limits: state.budgetDailyLimits,
          activeBudgetId: state.activeBudgetId,
          onSelect: ActiveBudgetSelector.select,
          onOpenActive: () => ActiveBudgetSelector.open(context),
        ),
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
      primary: [
        FadeSlideIn(
          index: _Stagger.top,
          child: DashboardHeader(
            budgetName: safeToSpend.budgetName,
            caption: AppDates.range(safeToSpend.startDate, safeToSpend.endDate),
            onSwitchBudget: () => ActiveBudgetSelector.open(context),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FadeSlideIn(
          index: _Stagger.top,
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
            index: _Stagger.summary,
            child: AppSurface(
              level: SurfaceLevel.sunken,
              child: SafeToSpendBreakdownCard(
                key: ValueKey('breakdown_${safeToSpend.budgetId}'),
                safeToSpend: safeToSpend,
              ),
            ),
          ),
          ..._notices(context, safeToSpend, index: _Stagger.summary),
        ],
        const SizedBox(height: _sectionGap),
        FadeSlideIn(
          index: _Stagger.bills,
          child: UpcomingBillsSection(
            bills: state.upcomingBills,
            unavailable: state.upcomingBillsUnavailable,
            hasBills: state.hasBills,
            onRetry: () =>
                context.read<DashboardBloc>().add(const DashboardRefresh()),
            activeBudgetId: state.activeBudgetId,
            setAsideBillIds: {
              for (final o in safeToSpend.commitments) o.billId,
            },
            budgetNames: {
              for (final limit in state.otherBudgetLimits)
                limit.budgetId: limit.budgetName,
              state.activeBudgetId: safeToSpend.budgetName,
            },
          ),
        ),
        const PayLaterHomeRow(),
      ],
      secondary: [
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
/// Home's scroll view. On a phone the sections stack in one column, the
/// [primary] ones (today's figure and what it depends on) first. From
/// [_twoColumnWidth] the [secondary] ones (pace, insights, other budgets,
/// recent expenses) move into a second column beside them.
class _DashboardScroll extends StatelessWidget {
  final List<Widget> primary;
  final List<Widget> secondary;

  const _DashboardScroll({required this.primary, required this.secondary});

  /// The Material "expanded" window width: tablets in landscape, large
  /// tablets and foldables open.
  static const double _twoColumnWidth = 840;
  static const double _twoColumnMaxWidth = 1120;

  Widget _column(List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: children,
  );

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns = constraints.maxWidth >= _twoColumnWidth;
          // The second column starts level with the first, without the gap
          // that separates it from the sections above on a phone.
          final side = secondary.skipWhile((w) => w is SizedBox).toList();
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.pagePadding,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: twoColumns
                        ? _twoColumnMaxWidth
                        : AppSizes.contentMaxWidth,
                  ),
                  child: twoColumns
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _column(primary)),
                            const SizedBox(width: AppSpacing.xl),
                            Expanded(child: _column(side)),
                          ],
                        )
                      : _column([...primary, ...secondary]),
                ),
              ),
            ],
          );
        },
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
      index: _Stagger.rest,
      child: AppSection(
        title: 'Other budgets today',
        subtitle: 'Each budget has its own safe amount',
        child: AppGroupedList(
          dividerIndent: AppSizes.avatarSm + AppSpacing.md,
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

/// The latest expenses. With [todayOnly] (a running budget), only today's,
/// under "Today": the ring above is today's story, and the rest of the
/// history is one tap away in Activity.
List<Widget> _recentExpenses(
  BuildContext context,
  List<RecentExpenseEntity> all,
  String currency, {
  DateTime? today,
  bool todayOnly = false,
}) {
  final theme = Theme.of(context);
  final day = todayOnly ? today : null;
  final expenses = day == null
      ? all
      : [
          for (final e in all)
            if (e.date.year == day.year &&
                e.date.month == day.month &&
                e.date.day == day.day)
              e,
        ];
  final muted = theme.textTheme.bodySmall?.copyWith(
    color: theme.colorScheme.onSurfaceVariant,
  );
  return [
    const SizedBox(height: _sectionGap),
    FadeSlideIn(
      index: _Stagger.rest,
      child: AppSection(
        title: day == null ? 'Recent' : 'Today',
        subtitle: day == null || expenses.isEmpty
            ? null
            : '${expenses.length} ${expenses.length == 1 ? 'expense' : 'expenses'} · '
                  '${AppMoney.format(expenses.fold<double>(0, (sum, e) => sum + e.amount), currency: currency)}',
        action: all.isEmpty || day != null
            ? null
            : TextButton(
                onPressed: () => context.go('/app/expenses'),
                child: const Text('See all'),
              ),
        child: expenses.isEmpty && all.isNotEmpty
            ? Text('Nothing spent today yet.', style: muted)
            : expenses.isEmpty
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
                    style: AppTheme.tonal(context),
                    onPressed: () => QuickAddSheet.show(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add expense'),
                  ),
                ],
              )
            : AppGroupedList(
                dividerIndent: AppSizes.avatarSm + AppSpacing.md,
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
    final theme = Theme.of(context);
    // Blueprint: the empty ring and one line explain the whole app.
    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: TargetRing(
              spent: 0,
              target: 1,
              diameter: 180,
              stroke: 14,
              semanticsLabel: 'No target yet',
              child: Text(
                'No target yet',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            header: true,
            child: Text(
              'Set a daily target',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'A budget gives you a daily safe-spending amount and keeps every '
            'expense in context.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () async {
              await context.pushUnique('/app/budgets/create');
              if (context.mounted) {
                context.read<DashboardBloc>().add(const DashboardRefresh());
              }
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create budget'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => context.pushUnique('/app/budgets/all'),
            child: const Text('Open budgets'),
          ),
        ],
      ),
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
