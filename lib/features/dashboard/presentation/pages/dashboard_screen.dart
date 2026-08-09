import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../budget/presentation/widgets/active_budget_selector.dart';
import '../../domain/entities/recent_expense_entity.dart';
import '../../domain/entities/smart_insight_entity.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../widgets/budget_hero_card.dart';
import '../widgets/dashboard_error_widget.dart';
import '../widgets/empty_dashboard_state.dart';
import '../widgets/insight_card.dart';
import '../widgets/recent_expense_tile.dart';
import '../widgets/today_spending_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    context.read<DashboardBloc>().add(const DashboardLoadData());
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            return switch (state) {
              DashboardInitial() ||
              DashboardLoading() => const _DashboardSkeleton(),
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
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Expense'),
        tooltip: 'Add a new expense',
      ),
    );
  }

  Widget _buildContent(BuildContext context, DashboardLoaded state) {
    final summary = state.budgetSummary;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<DashboardBloc>().add(const DashboardRefresh());
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: FadeTransition(
          opacity: _fadeController,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ActiveBudgetSelector(),
                  const SizedBox(height: AppSpacing.md),

                  // Hero
                  BudgetHeroCard(summary: summary),
                  const SizedBox(height: AppSpacing.md),

                  // Budget Overview (Budget / Spent / Remaining)
                  BudgetOverviewCard(summary: summary),
                  const SizedBox(height: AppSpacing.md),

                  // Today's Spending
                  TodaySpendingCard(summary: summary),
                  const SizedBox(height: AppSpacing.md),

                  // Budget Timeline
                  BudgetTimelineCard(summary: summary),
                  const SizedBox(height: AppSpacing.lg),

                  // Recent Expenses
                  SectionHeader(
                    title: 'Recent Expenses',
                    subtitle: state.recentExpenses.isEmpty
                        ? 'No expenses in this budget period'
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
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: EmptyState(
                        icon: Icons.receipt_long_rounded,
                        title: "You're ready to start",
                        message:
                            'Add your first expense and we\'ll start tracking '
                            'your budget.',
                        actionLabel: 'Add Expense',
                        actionIcon: Icons.add_rounded,
                        onAction: () {
                          context.push('/app/expenses/add');
                        },
                      ),
                    )
                  else
                    _RecentExpenseList(expenses: state.recentExpenses),
                  const SizedBox(height: AppSpacing.lg),

                  // Smart Insights
                  if (state.insights.isNotEmpty) ...[
                    const SectionHeader(title: 'Smart Insights'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildInsights(state.insights),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ],
              ),
            ),
          ),
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
}

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

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SkeletonBox(width: 200, height: 52, radius: 16),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 180, radius: 24),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 120, radius: 20),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 120, radius: 20),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 100, radius: 20),
        ],
      ),
    );
  }
}
