import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/app_notice.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/delayed_reveal.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../budget/presentation/widgets/active_budget_selector.dart';
import '../../../dashboard/domain/entities/smart_insight_entity.dart';
import '../../../dashboard/presentation/widgets/home_insights.dart';
import '../../../expenses/domain/entities/expense_history_filter.dart';
import '../../../expenses/presentation/history/widgets/filter_bottom_sheet.dart';
import '../../../expenses/presentation/quick_add/quick_add_sheet.dart';
import '../../domain/entities/report_data.dart';
import '../../domain/entities/report_period.dart';
import '../bloc/reports_bloc.dart';
import '../bloc/reports_event.dart';
import '../bloc/reports_state.dart';
import '../widgets/bar_chart_card.dart';
import '../widgets/category_comparison_card.dart';
import '../widgets/category_ranking.dart';
import '../widgets/daily_columns_chart.dart';
import '../widgets/empty_reports_state.dart';
import '../widgets/period_selector.dart';
import '../widgets/planned_vs_actual.dart';
import '../widgets/report_export.dart';
import '../widgets/report_total.dart';
import '../widgets/reports_error_widget.dart';
import '../widgets/weekday_rhythm.dart';

/// Reports tab. Reading order: what was spent and how that compares → the
/// plan against it (for "This Budget") → where it went → day by day →
/// the weekly rhythm → the few insights that add something.
///
/// Dates are chosen in one place, the period chips and range above the
/// report; the filter sheet narrows by category, amount, tags and receipts
/// only. Export lives in the menu. A failed refresh keeps the last report
/// on screen with a retry.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _exporting = false;

  /// Shows the slim progress bar. Pull-to-refresh already has its own
  /// spinner, so a refresh does not count.
  static bool _isBusy(ReportsState state) =>
      state.status == ReportsStatus.loading;

  @override
  void initState() {
    super.initState();
    context.read<ReportsBloc>().add(const ReportsLoad());
  }

  Future<void> _openFilterSheet() async {
    final bloc = context.read<ReportsBloc>();
    final result = await showFilterBottomSheet(
      context,
      current: bloc.state.filter,
      categories: bloc.state.data?.categories ?? const [],
      showDates: false,
    );
    if (result == null || !mounted) return;
    // Dates come from the period alone, so the range shown is the range
    // used (review: the sheet's dates overrode the period silently).
    bloc.add(
      ReportsFilterChanged(result.copyWithDateFrom(null).copyWithDateTo(null)),
    );
  }

  Future<void> _pickCustomRange() async {
    final bloc = context.read<ReportsBloc>();
    final now = DateTime.now();
    final current = bloc.state.data?.range;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: current == null
          ? null
          : DateTimeRange(
              start: current.start,
              end: current.end.isAfter(now) ? now : current.end,
            ),
      helpText: 'Report period',
      saveText: 'Apply',
    );
    if (picked == null || !mounted) return;
    bloc.add(
      ReportsPeriodChanged(
        ReportPeriod.custom,
        customStart: picked.start,
        customEnd: picked.end,
      ),
    );
  }

  void _onPeriodSelected(ReportPeriod period) {
    if (period == ReportPeriod.custom) {
      _pickCustomRange();
    } else {
      context.read<ReportsBloc>().add(ReportsPeriodChanged(period));
    }
  }

  Future<void> _export({required bool csv}) async {
    final data = context.read<ReportsBloc>().state.data;
    if (data == null || _exporting) return;
    setState(() => _exporting = true);
    await ReportExport.run(context, data, csv: csv);
    if (mounted) setState(() => _exporting = false);
  }

  Future<void> _refresh() async {
    final bloc = context.read<ReportsBloc>();
    final done = bloc.stream
        .firstWhere(
          (s) =>
              s.status == ReportsStatus.loaded ||
              s.status == ReportsStatus.error,
        )
        .timeout(const Duration(seconds: 8), onTimeout: () => bloc.state);
    bloc.add(const ReportsRefresh());
    await done;
  }

  void _retry() => context.read<ReportsBloc>().add(const ReportsRefresh());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          BlocBuilder<ReportsBloc, ReportsState>(
            buildWhen: (a, b) => a.filter != b.filter,
            builder: (context, state) => IconButton(
              key: const Key('reportsFilter'),
              tooltip: state.filter.isActive
                  ? 'Filters on · tap to change'
                  : 'Filter report',
              onPressed: _openFilterSheet,
              icon: Badge(
                isLabelVisible: state.filter.isActive,
                smallSize: 8,
                child: const Icon(Icons.filter_list_rounded),
              ),
            ),
          ),
          BlocBuilder<ReportsBloc, ReportsState>(
            buildWhen: (a, b) => !identical(a.data, b.data),
            builder: (context, state) {
              final canExport =
                  state.data != null && !state.data!.isEmpty && !_exporting;
              return PopupMenuButton<bool>(
                key: const Key('reportsMenu'),
                tooltip: 'More',
                onSelected: (csv) => _export(csv: csv),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: true,
                    enabled: canExport,
                    child: const ListTile(
                      leading: Icon(Icons.table_chart_outlined),
                      title: Text('Export CSV'),
                    ),
                  ),
                  PopupMenuItem(
                    value: false,
                    enabled: canExport,
                    child: const ListTile(
                      leading: Icon(Icons.picture_as_pdf_outlined),
                      title: Text('Export PDF'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<ReportsBloc, ReportsState>(
        // Rebuilding on every status flip reconstructed the charts; they
        // only depend on the report itself.
        buildWhen: (prev, curr) =>
            !identical(prev.data, curr.data) ||
            !identical(prev.insights, curr.insights) ||
            prev.period != curr.period ||
            prev.followsBudget != curr.followsBudget ||
            prev.budget != curr.budget ||
            prev.filter != curr.filter ||
            prev.status != curr.status,
        builder: (context, state) {
          final data = state.data;
          final Widget child;
          if (data == null && state.status == ReportsStatus.error) {
            child = ReportsErrorWidget(
              key: const ValueKey('error'),
              message: state.errorMessage == ReportsBloc.noBudgetMessage
                  ? ReportsBloc.noBudgetMessage
                  : 'Something went wrong while reading your expenses. '
                        'Try again.',
              onRetry: _retry,
            );
          } else if (data == null) {
            child = const DelayedReveal(
              key: ValueKey('loading'),
              child: _ReportsSkeleton(),
            );
          } else {
            // Period and filter changes keep the previous report on screen
            // with a slim progress bar instead of dropping to a spinner.
            child = _ReportContent(
              key: const ValueKey('content'),
              state: state,
              data: data,
              busy: _isBusy(state),
              failed: state.status == ReportsStatus.error,
              onPeriodSelected: _onPeriodSelected,
              onBudget: () => context.read<ReportsBloc>().add(
                const ReportsBudgetPeriodSelected(),
              ),
              onEditRange: _pickCustomRange,
              onRefresh: _refresh,
              onRetry: _retry,
            );
          }
          return AppStateSwitcher(child: child);
        },
      ),
    );
  }
}

/// Which report insights to show: only those that say something the
/// screen does not already show as a figure or chart.
abstract final class ReportInsightFilter {
  /// Said by the total and its comparison, the ranking, the weekday chart,
  /// planned versus actual, or Home.
  static const Set<String> _shownElsewhere = {
    'no_data',
    'overview',
    'spending_decreased',
    'spending_increased',
    'top_category',
    'highest_spending_day',
    'projected_savings',
    'budget_exceeded',
  };

  static List<SmartInsight> visible(
    List<SmartInsight> insights, {
    required bool rhythmShown,
  }) => [
    for (final i in insights)
      if (!_shownElsewhere.contains(i.id) &&
          !(rhythmShown && i.id == 'weekend_spending'))
        i,
  ];
}

class _ReportContent extends StatelessWidget {
  final ReportsState state;
  final ReportData data;
  final bool busy;
  final bool failed;
  final ValueChanged<ReportPeriod> onPeriodSelected;
  final VoidCallback onBudget;
  final VoidCallback onEditRange;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;

  const _ReportContent({
    super.key,
    required this.state,
    required this.data,
    required this.busy,
    required this.failed,
    required this.onPeriodSelected,
    required this.onBudget,
    required this.onEditRange,
    required this.onRefresh,
    required this.onRetry,
  });

  static const double _gap = AppSpacing.xl;

  @override
  Widget build(BuildContext context) {
    final currency = data.currency ?? data.currentBudget?.currency ?? '';
    final range = data.range;
    final isWeek =
        !state.followsBudget &&
        (state.period == ReportPeriod.thisWeek ||
            state.period == ReportPeriod.lastWeek);
    final budget = state.budget;
    final showPlan =
        state.followsBudget && budget != null && !state.filter.isActive;
    final showDaily = range.dayCount <= 62;
    final showBuckets =
        !isWeek && range.dayCount > 14 && data.spendingBuckets.length > 1;
    final showRhythm =
        range.dayCount >= 7 && WeekdayRhythm.hasRhythm(data.timeAnalytics);
    final insights = ReportInsightFilter.visible(
      state.insights ?? const [],
      rhythmShown: showRhythm,
    );
    final count = data.categoryAnalytics.length;
    var index = 0;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.pagePadding,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSizes.contentMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const ActiveBudgetSelector(),
                      const SizedBox(height: AppSpacing.md),
                      PeriodSelector(
                        selected: state.period,
                        followsBudget: state.followsBudget,
                        onSelected: onPeriodSelected,
                        onBudget: onBudget,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ReportRangeLabel(range: range, onEdit: onEditRange),
                      if (failed) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AppNotice(
                          key: const ValueKey('reportStale'),
                          tone: AppTone.caution,
                          icon: Icons.cloud_off_rounded,
                          title: "Couldn't update the report",
                          message: 'This is the last report that loaded.',
                          action: TextButton(
                            onPressed: onRetry,
                            child: const Text('Retry'),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),

                      // Sections stay mounted across period and filter
                      // changes so amounts and bars animate to their new
                      // values; only "nothing here" and a populated report
                      // cross-fade.
                      AnimatedSwitcher(
                        duration: AppMotion.respectReducedMotion(
                          context,
                          AppMotion.standard,
                        ),
                        switchInCurve: AppMotion.enter,
                        switchOutCurve: AppMotion.exit,
                        layoutBuilder: (current, previous) => Stack(
                          alignment: Alignment.topCenter,
                          children: [...previous, ?current],
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(data.isEmpty ? 'empty' : 'report'),
                          child: data.isEmpty
                              ? ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: 420,
                                  ),
                                  child: EmptyReportsState(
                                    filtered: state.filter.isActive,
                                    onAddExpense: () =>
                                        QuickAddSheet.show(context),
                                    onClearFilters: () =>
                                        context.read<ReportsBloc>().add(
                                          const ReportsFilterChanged(
                                            ExpenseHistoryFilter(),
                                          ),
                                        ),
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    FadeSlideIn(
                                      index: index++,
                                      child: ReportTotal(
                                        data: data,
                                        currency: currency,
                                      ),
                                    ),
                                    if (showPlan) ...[
                                      const SizedBox(height: _gap),
                                      FadeSlideIn(
                                        index: index++,
                                        child: PlannedVsActual(
                                          budget: budget,
                                          spent: data.overview.totalSpending,
                                          // The same "now" the report's range was taken from.
                                          now: context
                                              .read<ReportsBloc>()
                                              .clock(),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: _gap),
                                    FadeSlideIn(
                                      index: index++,
                                      child: AppSection(
                                        title: 'Where it went',
                                        subtitle:
                                            '$count '
                                            '${count == 1 ? 'category' : 'categories'}'
                                            ' · tap one to see its expenses',
                                        child: CategoryRanking(
                                          analytics: data.categoryAnalytics,
                                          categories: data.categories,
                                          expenses: data.filteredExpenses,
                                          currency: currency,
                                        ),
                                      ),
                                    ),
                                    if (CategoryComparisonCard.hasComparison(
                                      data.categoryComparison,
                                    )) ...[
                                      const SizedBox(height: AppSpacing.lg),
                                      FadeSlideIn(
                                        index: index++,
                                        child: CategoryComparisonCard(
                                          comparison: data.categoryComparison,
                                          categories: data.categories,
                                          range: range,
                                          currency: currency,
                                        ),
                                      ),
                                    ],
                                    if (showDaily) ...[
                                      const SizedBox(height: _gap),
                                      FadeSlideIn(
                                        index: index++,
                                        child: AppSection(
                                          title: 'Day by day',
                                          child: DailyColumnsChart(
                                            points: data.dailySpending,
                                            average: data
                                                .overview
                                                .averageDailySpending,
                                            currency: currency,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (showBuckets) ...[
                                      const SizedBox(height: _gap),
                                      FadeSlideIn(
                                        index: index++,
                                        child: BarChartCard(
                                          buckets: data.spendingBuckets,
                                          currency: currency,
                                        ),
                                      ),
                                    ],
                                    if (showRhythm) ...[
                                      const SizedBox(height: _gap),
                                      FadeSlideIn(
                                        index: index++,
                                        child: AppSection(
                                          title: 'Weekly rhythm',
                                          subtitle:
                                              'Spending by day of the week',
                                          child: WeekdayRhythm(
                                            analytics: data.timeAnalytics,
                                            currency: currency,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (insights.isNotEmpty) ...[
                                      const SizedBox(height: _gap),
                                      FadeSlideIn(
                                        index: index++,
                                        child: AppSection(
                                          title: 'Worth knowing',
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              for (final insight in insights)
                                                InsightRow(insight: insight),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: AppSpacing.xl),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Built only while busy: an always-mounted indeterminate bar keeps
        // its ticker running for the life of the screen.
        if (busy)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: AppSizes.progressThin),
          ),
      ],
    );
  }
}

class _ReportsSkeleton extends StatelessWidget {
  const _ReportsSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: AppSpacing.pagePadding,
        children: [
          const SkeletonBox(height: 56, radius: AppSpacing.radiusMd),
          const SizedBox(height: AppSpacing.md),
          const SkeletonBox(height: 32, radius: AppSpacing.radiusSm),
          const SizedBox(height: AppSpacing.lg),
          SkeletonText(style: theme.textTheme.labelMedium, width: 60),
          const SizedBox(height: AppSpacing.xs),
          const SkeletonBox(width: 180, height: 36),
          const SizedBox(height: AppSpacing.xl),
          SkeletonText(style: theme.textTheme.titleMedium, width: 140),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < 4; i++)
            const SkeletonListTile(leadingSize: AppSizes.avatarSm),
        ],
      ),
    );
  }
}
