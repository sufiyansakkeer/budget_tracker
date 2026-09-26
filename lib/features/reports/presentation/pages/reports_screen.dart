import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../budget/presentation/widgets/active_budget_selector.dart';
import '../../../expenses/domain/entities/expense_history_filter.dart';
import '../../../expenses/presentation/history/widgets/filter_bottom_sheet.dart';
import '../../domain/entities/report_data.dart';
import '../../domain/entities/report_period.dart';
import '../../domain/usecases/export_csv_usecase.dart';
import '../../domain/usecases/export_pdf_usecase.dart';
import '../bloc/reports_bloc.dart';
import '../bloc/reports_event.dart';
import '../bloc/reports_state.dart';
import '../widgets/bar_chart_card.dart';
import '../widgets/budget_utilization_card.dart';
import '../widgets/category_comparison_card.dart';
import '../widgets/empty_reports_state.dart';
import '../widgets/export_buttons.dart';
import '../widgets/insight_card.dart';
import '../widgets/line_chart_card.dart';
import '../widgets/period_selector.dart';
import '../widgets/pie_chart_card.dart';
import '../widgets/report_overview_card.dart';
import '../widgets/reports_error_widget.dart';
import '../widgets/time_analytics_card.dart';
import '../widgets/weekly_comparison_card.dart';
import '../../../dashboard/domain/entities/smart_insight_entity.dart';
import '../../../../core/navigation/push_unique.dart';

/// Reports tab. Reading order: how much did I spend → how is the budget
/// doing → where did it go → how did it move over time → patterns →
/// insights → export.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const _insightsCollapsed = 3;

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
    );
    if (result != null && mounted) bloc.add(ReportsFilterChanged(result));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          BlocBuilder<ReportsBloc, ReportsState>(
            buildWhen: (a, b) => a.filter != b.filter,
            builder: (context, state) => IconButton(
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
        ],
      ),
      body: BlocBuilder<ReportsBloc, ReportsState>(
        // Rebuilding on every status flip reconstructed all three fl_chart
        // data graphs; the charts only depend on the report itself.
        buildWhen: (prev, curr) =>
            !identical(prev.data, curr.data) ||
            !identical(prev.insights, curr.insights) ||
            prev.period != curr.period ||
            prev.filter != curr.filter ||
            prev.errorMessage != curr.errorMessage ||
            _isBusy(prev) != _isBusy(curr),
        builder: (context, state) {
          final data = state.data;
          final Widget child;
          if (state.status == ReportsStatus.error) {
            child = ReportsErrorWidget(
              key: const ValueKey('error'),
              message: state.errorMessage ?? "Couldn't load the report",
              onRetry: () =>
                  context.read<ReportsBloc>().add(const ReportsRefresh()),
            );
          } else if (data == null) {
            child = const _ReportsSkeleton(key: ValueKey('loading'));
          } else {
            // Period/filter changes keep the previous report on screen with a
            // slim progress bar instead of dropping to a spinner.
            child = _ReportContent(
              key: const ValueKey('content'),
              state: state,
              data: data,
              busy: _isBusy(state),
              onPeriodSelected: _onPeriodSelected,
              onEditRange: _pickCustomRange,
              onRefresh: _refresh,
              insightsCollapsed: _insightsCollapsed,
            );
          }
          return AppStateSwitcher(child: child);
        },
      ),
    );
  }
}

class _ReportContent extends StatelessWidget {
  final ReportsState state;
  final ReportData data;
  final bool busy;
  final ValueChanged<ReportPeriod> onPeriodSelected;
  final VoidCallback onEditRange;
  final Future<void> Function() onRefresh;
  final int insightsCollapsed;

  const _ReportContent({
    super.key,
    required this.state,
    required this.data,
    required this.busy,
    required this.onPeriodSelected,
    required this.onEditRange,
    required this.onRefresh,
    required this.insightsCollapsed,
  });

  @override
  Widget build(BuildContext context) {
    final currency = data.currentBudget?.currency ?? '';
    final insights = state.insights ?? const [];
    final isWeekPeriod =
        state.period == ReportPeriod.thisWeek ||
        state.period == ReportPeriod.lastWeek;
    final bucketUnit = state.period == ReportPeriod.thisYear ? 'month' : 'week';
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
                        onSelected: onPeriodSelected,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ReportRangeLabel(range: data.range, onEdit: onEditRange),
                      const SizedBox(height: AppSpacing.md),

                      // The cards stay mounted across period and filter
                      // changes so amounts, bars and lines animate from the
                      // old values to the new ones; only the switch between
                      // "nothing in this period" and a populated report
                      // cross-fades.
                      AnimatedSwitcher(
                        duration: AppMotion.respectReducedMotion(
                          context,
                          AppMotion.standard,
                        ),
                        switchInCurve: AppMotion.enter,
                        switchOutCurve: AppMotion.exit,
                        layoutBuilder: (current, previous) => Stack(
                          alignment: Alignment.topCenter,
                          children: [...previous, if (current != null) current],
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(data.isEmpty ? 'empty' : 'report'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (data.isEmpty)
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: 420,
                                  ),
                                  child: EmptyReportsState(
                                    filtered: state.filter.isActive,
                                    onAddExpense: () =>
                                        context.pushUnique('/app/expenses/add'),
                                    onClearFilters: () =>
                                        context.read<ReportsBloc>().add(
                                          const ReportsFilterChanged(
                                            ExpenseHistoryFilter(),
                                          ),
                                        ),
                                  ),
                                )
                              else ...[
                                // 1. Total spending
                                FadeSlideIn(
                                  index: index++,
                                  child: ReportSummaryCard(
                                    overview: data.overview,
                                    trend: data.trend,
                                    range: data.range,
                                    currency: currency,
                                  ),
                                ),

                                // 2. Budget progress (current month only)
                                if (data.currentBudget != null) ...[
                                  const SizedBox(height: AppSpacing.smd),
                                  FadeSlideIn(
                                    index: index++,
                                    child: BudgetUtilizationCard(
                                      spent: data.currentMonthSpent,
                                      remaining:
                                          (data.currentMonthBudget -
                                                  data.currentMonthSpent)
                                              .clamp(0, double.infinity),
                                      monthly: data.currentMonthBudget,
                                      currency: currency,
                                    ),
                                  ),
                                ],

                                // 3. Where it went
                                const SizedBox(height: AppSpacing.lg),
                                FadeSlideIn(
                                  index: index++,
                                  child: CategoryBreakdownCard(
                                    slices: data.categorySlices,
                                    analytics: data.categoryAnalytics,
                                    categories: data.categories,
                                    currency: currency,
                                  ),
                                ),

                                // 3b. Movers vs the previous period
                                if (CategoryComparisonCard.hasComparison(
                                  data.categoryComparison,
                                )) ...[
                                  const SizedBox(height: AppSpacing.smd),
                                  FadeSlideIn(
                                    index: index++,
                                    child: CategoryComparisonCard(
                                      comparison: data.categoryComparison,
                                      categories: data.categories,
                                      range: data.range,
                                      currency: currency,
                                    ),
                                  ),
                                ],

                                // 4. Over time
                                const SizedBox(height: AppSpacing.lg),
                                const SectionHeader(title: 'Over time'),
                                FadeSlideIn(
                                  index: index++,
                                  child: LineChartCard(
                                    points: data.dailySpending,
                                    currency: currency,
                                  ),
                                ),
                                if (!isWeekPeriod &&
                                    data.spendingBuckets.length > 1) ...[
                                  const SizedBox(height: AppSpacing.smd),
                                  FadeSlideIn(
                                    index: index++,
                                    child: BarChartCard(
                                      buckets: data.spendingBuckets,
                                      currency: currency,
                                      unit: bucketUnit,
                                    ),
                                  ),
                                ],
                                if (data.weeklyComparison != null &&
                                    data.weeklyComparison!.hasPrevious) ...[
                                  const SizedBox(height: AppSpacing.smd),
                                  FadeSlideIn(
                                    index: index++,
                                    child: WeeklyComparisonCard(
                                      comparison: data.weeklyComparison!,
                                      currency: currency,
                                    ),
                                  ),
                                ],

                                // 5. Patterns
                                const SizedBox(height: AppSpacing.lg),
                                FadeSlideIn(
                                  index: index++,
                                  child: TimeAnalyticsCard(
                                    analytics: data.timeAnalytics,
                                    trend: data.trend,
                                    dailySpending: data.dailySpending,
                                    currency: currency,
                                  ),
                                ),

                                // 6. Insights
                                if (insights.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.lg),
                                  const SectionHeader(
                                    title: 'Smart insights',
                                    infoContent: InfoContent(
                                      title: 'Smart insights',
                                      whatIsThis:
                                          'Short, rule-based observations about the '
                                          'report you are viewing. They are simple '
                                          "calculations on your active budget's "
                                          'expenses, not AI.',
                                      howIsItCalculated:
                                          'Insights are generated from the figures '
                                          'shown on this screen:\n'
                                          '• Spending compared with the same number '
                                          'of days before this period\n'
                                          '• The category with the largest share\n'
                                          '• The day of the week you spend the most '
                                          'on\n'
                                          '• Whether weekends take a large share\n'
                                          '• How much of the active budget is left '
                                          '(current month only)\n'
                                          '• Whether the second half of the period '
                                          'was lower than the first\n'
                                          '• Whether daily spending is very '
                                          'consistent',
                                      privacyNote:
                                          'All analysis runs on your device. No data '
                                          'leaves your phone.',
                                    ),
                                  ),
                                  _InsightsList(
                                    insights: insights,
                                    collapsed: insightsCollapsed,
                                    baseIndex: index,
                                  ),
                                ],

                                // 7. Export
                                const SizedBox(height: AppSpacing.lg),
                                const SectionHeader(
                                  title: 'Export',
                                  subtitle: 'Share this report as a file',
                                ),
                                ExportButtons(
                                  data: data,
                                  exportCsvUseCase: const ExportCsvUseCase(),
                                  exportPdfUseCase: const ExportPdfUseCase(),
                                ),
                                const SizedBox(height: AppSpacing.xl),
                              ],
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
        // its ticker running (and repainting) for the life of the screen.
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
  const _ReportsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: AppSpacing.pagePadding,
        children: const [
          SkeletonBox(height: 56, radius: AppSpacing.radiusMd),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 36, radius: AppSpacing.radiusFull),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(height: 180, radius: AppSpacing.radiusLg),
          SizedBox(height: AppSpacing.smd),
          SkeletonBox(height: 120, radius: AppSpacing.radiusLg),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(height: 320, radius: AppSpacing.radiusLg),
        ],
      ),
    );
  }
}

/// The insights list with its own show-more state.
///
/// Keeping the toggle here means expanding two text cards does not rebuild
/// the report's three charts, which happens when the state lives on the
/// screen above the BlocBuilder.
class _InsightsList extends StatefulWidget {
  final List<SmartInsight> insights;
  final int collapsed;
  final int baseIndex;

  const _InsightsList({
    required this.insights,
    required this.collapsed,
    required this.baseIndex,
  });

  @override
  State<_InsightsList> createState() => _InsightsListState();
}

class _InsightsListState extends State<_InsightsList> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final insights = widget.insights;
    final visible = _showAll
        ? insights
        : insights.take(widget.collapsed).toList();

    // Expanding reveals the extra insights with a short stagger while the
    // section grows smoothly.
    return AnimatedSize(
      duration: AppMotion.respectReducedMotion(context, AppMotion.medium),
      curve: AppMotion.standardCurve,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < visible.length; i++)
            FadeSlideIn(
              key: ValueKey('insight_${visible[i].message}'),
              index: i < widget.collapsed
                  ? widget.baseIndex + i
                  : i - widget.collapsed,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: InsightCard(
                  message: visible[i].message,
                  type: visible[i].type,
                ),
              ),
            ),
          if (insights.length > widget.collapsed)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _showAll = !_showAll),
                child: Text(
                  _showAll
                      ? 'Show fewer'
                      : 'Show ${insights.length - widget.collapsed} more',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
