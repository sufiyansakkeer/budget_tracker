import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_section_header.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../budget/presentation/widgets/active_budget_selector.dart';
import '../../../bills/domain/entities/bill_entity.dart';
import '../../../bills/domain/entities/bill_enums.dart';
import '../../../budget/domain/entities/budget_summary_entity.dart';
import '../../domain/entities/recent_expense_entity.dart';
import '../../domain/entities/smart_insight_entity.dart';

import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../widgets/budget_daily_limits_section.dart';

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
    final budgetDailyLimits = state.budgetDailyLimits;

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

                  // ── Per-Budget Daily Spending Limits ──────────────────
                  BudgetDailyLimitsSection(budgetLimits: budgetDailyLimits),
                  const SizedBox(height: AppSpacing.md),

                  // ── Budget Overview (Remaining Budget) ────────────────
                  _OverallBudgetCard(summary: summary),
                  const SizedBox(height: AppSpacing.md),

                  // ── Budget Timeline ───────────────────────────────────
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
                            "Add your first expense and we'll start tracking "
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
                    InfoSectionHeader(
                      title: 'Upcoming Bills',
                      trailing: TextButton(
                        onPressed: () => context.push('/app/bills'),
                        child: const Text('View All'),
                      ),
                      infoContent: InfoContent(
                        title: 'Upcoming Bills',
                        whatIsThis:
                            'Bills that are scheduled to become due soon. '
                            'These are tracked separately from your regular '
                            'expenses.',
                        howIsItCalculated:
                            'The app looks at all bills that are due in the '
                            'near future and have not yet been marked as paid. '
                            'Bills are sorted by their due date.',
                        additionalNotes:
                            '• Bills shown here are due but not yet paid\n'
                            '• Mark a bill as paid to remove it from this list\n'
                            '• Bills are separate from your expense tracking\n'
                            '• Overdue bills are highlighted in red',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _UpcomingBillsList(bills: state.upcomingBills),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Smart Insights
                  if (state.insights.isNotEmpty) ...[
                    InfoSectionHeader(
                      title: 'Smart Insights',
                      infoContent: InfoContent(
                        title: 'Smart Insights',
                        whatIsThis:
                            'Smart Insights analyze your local budget and '
                            'expense data to identify spending patterns, '
                            'budget progress, and unusual behavior.',
                        howIsItCalculated:
                            'The insights engine examines your current budget '
                            'status, daily spending pace, weekly targets, '
                            'projected spending, and category behavior. '
                            'Up to 3 insights are shown, prioritized by '
                            'severity.',
                        additionalNotes:
                            'Types of analysis include:\n'
                            '• Critical overspending alerts\n'
                            '• Projected spending & budget risk\n'
                            '• Today\'s spending status\n'
                            '• Daily & weekly target performance\n'
                            '• Spending pace vs. safe allowance\n'
                            '• Budget progress updates\n'
                            '• Projected savings estimates',
                        privacyNote:
                            'All analysis runs on your device. No data leaves '
                            'your phone.',
                      ),
                    ),
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

// ── Overall Budget Card ──────────────────────────────────────────────────

/// Shows overall budget remaining across all active budgets.
/// This is the only "combined" view allowed — total remaining, NOT combined
/// daily spending limit.
class _OverallBudgetCard extends StatelessWidget {
  final BudgetSummaryEntity summary;

  const _OverallBudgetCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall Budget',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.format(
                    summary.remainingBudget,
                    code: summary.currency,
                  ),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'remaining',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          InfoIcon(
            content: InfoContent(
              title: 'Overall Budget',
              whatIsThis:
                  'The total remaining amount across all active budgets. '
                  "This combines all budgets' remaining balances.",
              howIsItCalculated:
                  'Sum of remaining amounts from all active budgets.\n\n'
                  'Note: Daily spending limits are calculated '
                  'separately for each budget and are NOT combined.',
              additionalNotes:
                  '• Combined total remaining is shown here for convenience\n'
                  '• Each budget\'s daily spending limit is independent\n'
                  '• Expenses are tracked per budget, not combined',
            ),
          ),
        ],
      ),
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
        final due = DateTime(
          bill.dueDate.year,
          bill.dueDate.month,
          bill.dueDate.day,
        );
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
                      isOverdue
                          ? Icons.warning_rounded
                          : Icons.receipt_long_rounded,
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
          SkeletonBox(height: 100, radius: 20),
        ],
      ),
    );
  }
}
