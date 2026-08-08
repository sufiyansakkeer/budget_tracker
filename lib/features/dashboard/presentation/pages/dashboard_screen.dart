import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../budget/domain/entities/budget_status.dart';
import '../../../budget/presentation/widgets/active_budget_selector.dart';
import '../../domain/entities/recent_expense_entity.dart';
import '../../domain/entities/smart_insight_entity.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../widgets/analytics_card.dart';
import '../widgets/budget_progress_card.dart';
import '../widgets/dashboard_error_widget.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_section_header.dart';
import '../widgets/empty_dashboard_state.dart';
import '../widgets/insight_card.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/recent_expense_tile.dart';
import '../widgets/summary_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    context.read<DashboardBloc>().add(const DashboardLoadData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            return switch (state) {
              DashboardInitial() || DashboardLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              DashboardLoaded() => _buildContent(context, state),
              DashboardEmpty() => const EmptyDashboardState(
                type: EmptyStateType.noBudget,
              ),
              DashboardError(:final message) => DashboardErrorWidget(
                message: message,
                onRetry: () {
                  context.read<DashboardBloc>().add(const DashboardRefresh());
                },
              ),
              _ => const SizedBox.shrink(),
            };
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/app/expenses/add');
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
        tooltip: 'Add a new expense',
      ),
    );
  }

  Widget _buildContent(BuildContext context, DashboardLoaded state) {
    final summary = state.budgetSummary;
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<DashboardBloc>().add(const DashboardRefresh());
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ActiveBudgetSelector(),
            const SizedBox(height: AppSpacing.md),
            DashboardHeader(
              currency: summary.currency,
              startDate: summary.startDate,
              endDate: summary.endDate,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Summary Cards
            _SummaryGrid(
              isWide: isWide,
              children: [
                SummaryCard(
                  title: 'Monthly Budget',
                  amount: summary.monthlyAmount,
                  currency: summary.currency,
                  icon: Icons.account_balance_wallet,
                ),
                SummaryCard(
                  title: 'Remaining',
                  amount: summary.remainingBudget,
                  currency: summary.currency,
                  icon: Icons.savings,
                  valueColor: _getRemainingColor(summary.status),
                ),
                SummaryCard(
                  title: 'Today\'s Spending',
                  amount: summary.todaySpending,
                  currency: summary.currency,
                  icon: Icons.today,
                ),
                SummaryCard(
                  title: 'Days Left',
                  amount: summary.remainingDays.toDouble(),
                  currency: '',
                  icon: Icons.calendar_today,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Today's Safe Spending Card
            SummaryCard(
              title: '',
              amount: summary.dailySafeSpending,
              currency: summary.currency,
              icon: Icons.trending_up,
              isHighlighted: true,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Budget Progress
            BudgetProgressCard(
              budgetUtilization: summary.budgetUtilization,
              totalSpent: summary.totalSpent,
              remainingBudget: summary.remainingBudget,
              currency: summary.currency,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Analytics Section
            const DashboardSectionHeader(title: 'Analytics'),
            const SizedBox(height: AppSpacing.sm),
            _AnalyticsGrid(
              isWide: isWide,
              children: [
                AnalyticsCard(
                  title: 'Avg Daily Spending',
                  value: summary.averageDailySpending,
                  currency: summary.currency,
                  icon: Icons.show_chart,
                ),
                AnalyticsCard(
                  title: 'Projected Savings',
                  value: summary.expectedSavings,
                  currency: summary.currency,
                  icon: Icons.trending_up,
                  isPositive: summary.expectedSavings >= 0,
                ),
                AnalyticsCard(
                  title: 'Projected Overspending',
                  value: summary.expectedOverspending,
                  currency: summary.currency,
                  icon: Icons.trending_down,
                  isPositive: summary.expectedOverspending <= 0,
                ),
                AnalyticsCard(
                  title: 'Period-End Projection',
                  value: summary.expectedPeriodEndSpending,
                  currency: summary.currency,
                  icon: Icons.bar_chart,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Smart Insights
            const DashboardSectionHeader(title: 'Smart Insights'),
            const SizedBox(height: AppSpacing.sm),
            _buildInsights(state.insights),
            const SizedBox(height: AppSpacing.lg),

            // Recent Expenses
            DashboardSectionHeader(
              title: 'Recent Expenses',
              subtitle: state.recentExpenses.isEmpty
                  ? 'No expenses this month'
                  : '${state.recentExpenses.length} expenses',
              trailing: state.recentExpenses.isNotEmpty
                  ? TextButton(
                      onPressed: () {
                        context.push('/app/expenses');
                      },
                      child: const Text('View All'),
                    )
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (state.recentExpenses.isEmpty)
              EmptyDashboardState(
                type: EmptyStateType.noExpenses,
                onAction: () {
                  context.push('/app/expenses/add');
                },
              )
            else
              _RecentExpenseList(expenses: state.recentExpenses),
            const SizedBox(height: AppSpacing.lg),

            // Quick Actions
            const DashboardSectionHeader(title: 'Quick Actions'),
            const SizedBox(height: AppSpacing.sm),
            _QuickActionsGrid(isWide: isWide),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildInsights(List<SmartInsight> insights) {
    return Column(
      children: insights
          .map(
            (insight) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: InsightCard(message: insight.message, type: insight.type),
            ),
          )
          .toList(),
    );
  }

  Color _getRemainingColor(BudgetStatus status) {
    switch (status) {
      case BudgetStatus.underBudget:
        return AppColors.safeGreen;
      case BudgetStatus.nearLimit:
        return AppColors.warningOrange;
      case BudgetStatus.overBudget:
        return AppColors.dangerRed;
    }
  }
}

/// Responsive grid for summary cards.
class _SummaryGrid extends StatelessWidget {
  final bool isWide;
  final List<Widget> children;

  const _SummaryGrid({required this.isWide, required this.children});

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = isWide ? 4 : 2;
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: isWide ? 1.8 : 1.5,
      children: children,
    );
  }
}

/// Responsive grid for analytics cards.
class _AnalyticsGrid extends StatelessWidget {
  final bool isWide;
  final List<Widget> children;

  const _AnalyticsGrid({required this.isWide, required this.children});

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = isWide ? 4 : 2;
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: isWide ? 3.2 : 2.3,
      children: children,
    );
  }
}

/// Responsive grid for quick action buttons.
class _QuickActionsGrid extends StatelessWidget {
  final bool isWide;

  const _QuickActionsGrid({required this.isWide});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        icon: Icons.add,
        label: 'Add Expense',
        onTap: () => context.push('/app/expenses/add'),
      ),
      (
        icon: Icons.history,
        label: 'History',
        onTap: () => context.push('/app/expenses'),
      ),
      (
        icon: Icons.bar_chart,
        label: 'Reports',
        onTap: () => context.push('/app/reports'),
      ),
      (
        icon: Icons.settings,
        label: 'Settings',
        onTap: () => context.push('/app/more'),
      ),
    ];

    if (isWide) {
      return Row(
        children: actions
            .map(
              (a) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: QuickActionButton(
                    icon: a.icon,
                    label: a.label,
                    onTap: a.onTap,
                  ),
                ),
              ),
            )
            .toList(),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: QuickActionButton(
                icon: actions[0].icon,
                label: actions[0].label,
                onTap: actions[0].onTap,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: QuickActionButton(
                icon: actions[1].icon,
                label: actions[1].label,
                onTap: actions[1].onTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: QuickActionButton(
                icon: actions[2].icon,
                label: actions[2].label,
                onTap: actions[2].onTap,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: QuickActionButton(
                icon: actions[3].icon,
                label: actions[3].label,
                onTap: actions[3].onTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Lazy list of recent expense tiles.
class _RecentExpenseList extends StatelessWidget {
  final List<RecentExpenseEntity> expenses;

  const _RecentExpenseList({required this.expenses});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: expenses
          .map(
            (expense) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: RecentExpenseTile(expense: expense),
            ),
          )
          .toList(),
    );
  }
}
