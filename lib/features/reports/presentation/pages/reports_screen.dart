import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../expenses/presentation/history/widgets/filter_bottom_sheet.dart';
import '../../domain/entities/report_period.dart';
import '../../domain/usecases/export_csv_usecase.dart';
import '../../domain/usecases/export_pdf_usecase.dart';
import '../bloc/reports_bloc.dart';
import '../bloc/reports_event.dart';
import '../bloc/reports_state.dart';
import '../widgets/analytics_section.dart';
import '../widgets/bar_chart_card.dart';
import '../widgets/budget_utilization_card.dart';
import '../widgets/category_analytics_card.dart';
import '../widgets/empty_reports_state.dart';
import '../widgets/export_buttons.dart';
import '../widgets/insight_card.dart';
import '../widgets/line_chart_card.dart';
import '../widgets/period_selector.dart';
import '../widgets/pie_chart_card.dart';
import '../widgets/report_overview_card.dart';
import '../widgets/reports_error_widget.dart';
import '../widgets/time_analytics_card.dart';
import '../widgets/trend_card.dart';
import '../widgets/weekly_comparison_card.dart';

/// Reports & Analytics screen. Displays overview cards, charts, category
/// analytics, time analytics, smart insights, and export actions.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ReportsBloc>().add(const ReportsLoad());
  }

  Future<void> _openFilterSheet(ReportsState state) async {
    final categories = state.data?.categories ?? const [];
    final result = await showFilterBottomSheet(
      context,
      current: state.filter,
      categories: categories,
    );
    if (result != null && mounted) {
      context.read<ReportsBloc>().add(ReportsFilterChanged(result));
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final start = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month, 1),
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (start == null || !mounted) return;
    final end = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: start,
      lastDate: now,
    );
    if (end == null || !mounted) return;
    context.read<ReportsBloc>().add(
      ReportsPeriodChanged(
        ReportPeriod.custom,
        customStart: start,
        customEnd: end,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        actions: [
          IconButton(
            tooltip: 'Filter report',
            icon: const Icon(Icons.filter_list),
            onPressed: () =>
                _openFilterSheet(context.read<ReportsBloc>().state),
          ),
        ],
      ),
      body: BlocBuilder<ReportsBloc, ReportsState>(
        builder: (context, state) {
          return switch (state.status) {
            ReportsStatus.initial || ReportsStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            ReportsStatus.error => ReportsErrorWidget(
              message: state.errorMessage ?? 'Unable to load report',
              onRetry: () =>
                  context.read<ReportsBloc>().add(const ReportsRefresh()),
            ),
            ReportsStatus.loaded => _buildContent(context, state),
            ReportsStatus.refreshing =>
              state.data != null
                  ? _buildContent(context, state)
                  : const Center(child: CircularProgressIndicator()),
          };
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, ReportsState state) {
    final data = state.data;
    if (data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (data.isEmpty) {
      return Column(
        children: [
          PeriodSelector(selected: state.period, onSelected: _onPeriodSelected),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: EmptyReportsState(
              onAddExpense: () => context.push('/expenses/add'),
            ),
          ),
        ],
      );
    }

    final currency = data.currentBudget?.currency ?? '₹';

    return RefreshIndicator(
      onRefresh: () async {
        context.read<ReportsBloc>().add(const ReportsRefresh());
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PeriodSelector(
              selected: state.period,
              onSelected: _onPeriodSelected,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Overview cards
            ReportOverviewGrid(overview: data.overview, currency: currency),
            const SizedBox(height: AppSpacing.lg),

            // Budget utilization
            if (data.currentBudget != null) ...[
              BudgetUtilizationCard(
                spent: data.currentMonthSpent,
                remaining: (data.currentMonthBudget - data.currentMonthSpent)
                    .clamp(0, double.infinity),
                monthly: data.currentMonthBudget,
                currency: currency,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // Charts
            const AnalyticsSection(title: 'Charts'),
            const SizedBox(height: AppSpacing.sm),
            LineChartCard(points: data.dailySpending, currency: currency),
            const SizedBox(height: AppSpacing.md),
            BarChartCard(buckets: data.spendingBuckets, currency: currency),
            const SizedBox(height: AppSpacing.md),
            PieChartCard(
              slices: data.categorySlices,
              categories: data.categories,
              currency: currency,
            ),
            const SizedBox(height: AppSpacing.md),
            if (data.weeklyComparison != null) ...[
              WeeklyComparisonCard(
                comparison: data.weeklyComparison!,
                currency: currency,
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Category analytics
            const AnalyticsSection(title: 'Category Analytics'),
            const SizedBox(height: AppSpacing.sm),
            CategoryAnalyticsCard(
              analytics: data.categoryAnalytics,
              currency: currency,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Time analytics
            const AnalyticsSection(title: 'Time Analytics'),
            const SizedBox(height: AppSpacing.sm),
            TimeAnalyticsCard(
              analytics: data.timeAnalytics,
              currency: currency,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Trends
            const AnalyticsSection(title: 'Spending Trends'),
            const SizedBox(height: AppSpacing.sm),
            TrendCard(trend: data.trend, currency: currency),
            const SizedBox(height: AppSpacing.lg),

            // Smart insights
            const AnalyticsSection(title: 'Smart Insights'),
            const SizedBox(height: AppSpacing.sm),
            if (state.insights == null || state.insights!.isEmpty)
              const Text('No insights available.')
            else
              for (final insight in state.insights!)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: InsightCard(
                    message: insight.message,
                    type: insight.type,
                  ),
                ),
            const SizedBox(height: AppSpacing.lg),

            // Export
            const AnalyticsSection(title: 'Export Report'),
            const SizedBox(height: AppSpacing.sm),
            ExportButtons(
              data: data,
              exportCsvUseCase: const ExportCsvUseCase(),
              exportPdfUseCase: const ExportPdfUseCase(),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
