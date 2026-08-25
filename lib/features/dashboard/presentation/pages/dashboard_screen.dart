import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../budget/presentation/widgets/active_budget_selector.dart';
import '../../../bills/domain/entities/bill_entity.dart';
import '../../../bills/domain/entities/bill_enums.dart';
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
      floatingActionButton: _DashboardFab(),
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

                  // Quick Actions
                  const SectionHeader(title: 'Quick Actions'),
                  const SizedBox(height: AppSpacing.sm),
                  const _QuickActionsGrid(),
                  const SizedBox(height: AppSpacing.lg),

                  // Recent Expenses
                  SectionHeader(
                    title: 'Recent Transactions',
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

                  // Upcoming Bills
                  if (state.upcomingBills.isNotEmpty) ...[
                    SectionHeader(
                      title: 'Upcoming Bills',
                      trailing: TextButton(
                        onPressed: () => context.push('/app/bills'),
                        child: const Text('View All'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _UpcomingBillsList(bills: state.upcomingBills),
                    const SizedBox(height: AppSpacing.lg),
                  ],

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

// ── Quick Actions ──────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.add_rounded,
            label: 'Add Expense',
            onTap: () => context.push('/app/expenses/add'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.receipt_long_rounded,
            label: 'Add Bill',
            onTap: () => context.push('/app/bills/add'),
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer,
      borderRadius: AppSpacing.borderRadiusMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Floating Action Button ─────────────────────────────────────────────

class _DashboardFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, -8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        switch (value) {
          case 'expense':
            context.push('/app/expenses/add');
          case 'bill':
            context.push('/app/bills/add');
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'expense',
          child: Row(
            children: [
              Icon(Icons.add_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              const Text('Add Expense'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'bill',
          child: Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Text('Add Bill'),
            ],
          ),
        ),
      ],
      child: FloatingActionButton.extended(
        onPressed: null, // Handled by PopupMenuButton
        backgroundColor: AppColors.primary,
        heroTag: 'dashboard_fab',
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
        tooltip: 'Quick add',
      ),
    );
  }
}

// ── Recent Expenses List ───────────────────────────────────────────────

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

// ── Upcoming Bills List ────────────────────────────────────────────────

class _UpcomingBillsList extends StatelessWidget {
  final List<BillEntity> bills;

  const _UpcomingBillsList({required this.bills});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: bills.map((bill) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final due = DateTime(bill.dueDate.year, bill.dueDate.month, bill.dueDate.day);
        final daysUntil = due.difference(today).inDays;
        final isOverdue = bill.status == BillStatus.overdue;
        final isDueToday = bill.status == BillStatus.dueToday;

        String dueText;
        Color dueColor;
        if (isDueToday) {
          dueText = 'Due today';
          dueColor = AppColors.warning;
        } else if (isOverdue) {
          dueText = '${today.difference(due).inDays} days overdue';
          dueColor = AppColors.error;
        } else if (daysUntil == 1) {
          dueText = 'Due tomorrow';
          dueColor = AppColors.primary;
        } else {
          dueText = 'Due in $daysUntil days';
          dueColor = AppColors.primary;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.smd),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: dueColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isOverdue ? Icons.warning_rounded : Icons.receipt_long_rounded,
                      color: dueColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.smd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bill.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          dueText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: dueColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(
                      bill.amount,
                      code: bill.currency,
                      decimalDigits: 0,
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isOverdue ? AppColors.error : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Loading Skeleton ───────────────────────────────────────────────────

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
