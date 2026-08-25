import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../../core/widgets/money_text.dart';
import '../../domain/entities/bill_entity.dart';
import '../../domain/entities/bill_enums.dart';
import '../bloc/bill_bloc.dart';
import '../bloc/bill_event.dart';
import '../bloc/bill_state.dart';
import 'bill_widgets.dart';

/// Bills dashboard screen with summary cards, filters, and bill list.
class BillsListScreen extends StatefulWidget {
  const BillsListScreen({super.key});

  @override
  State<BillsListScreen> createState() => _BillsListScreenState();
}

class _BillsListScreenState extends State<BillsListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<BillBloc>().add(const BillLoadAll());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<BillBloc, BillState>(
          builder: (context, state) {
            if (state.status == BillBlocStatus.loading &&
                state.allBills.isEmpty) {
              return const _BillsSkeleton();
            }

            if (state.status == BillBlocStatus.error &&
                state.allBills.isEmpty) {
              return _BillsErrorWidget(
                message: state.message ?? 'Unable to load bills',
                onRetry: () =>
                    context.read<BillBloc>().add(const BillRefresh()),
              );
            }

            return _buildContent(context, state);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/app/bills/add'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Bill'),
        tooltip: 'Add a new bill',
      ),
    );
  }

  Widget _buildContent(BuildContext context, BillState state) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () async {
        context.read<BillBloc>().add(const BillRefresh());
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bills',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Track & manage your bills',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Summary cards
          if (state.allBills.isNotEmpty)
            SliverToBoxAdapter(
              child: _BillSummaryCards(state: state),
            ),

          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search bills...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            context
                                .read<BillBloc>()
                                .add(const BillSearchChanged(''));
                            setState(() {});
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.smd,
                  ),
                ),
                onChanged: (query) {
                  context.read<BillBloc>().add(BillSearchChanged(query));
                  setState(() {});
                },
              ),
            ),
          ),

          // Filter chips
          SliverToBoxAdapter(
            child: _BillFilterChips(
              currentFilter: state.filter,
              onFilterChanged: (filter) =>
                  context.read<BillBloc>().add(BillFilterChanged(filter)),
            ),
          ),

          // Bills list
          if (state.filteredBills.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(context, state),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final bill = state.filteredBills[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: BillCard(
                        bill: bill,
                        currency: bill.currency,
                        onTap: () =>
                            context.push('/app/bills/${bill.id}'),
                        onMarkPaid: () => _confirmMarkPaid(context, bill),
                      ),
                    );
                  },
                  childCount: state.filteredBills.length,
                ),
              ),
            ),

          // Bottom padding for FAB
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, BillState state) {
    if (state.allBills.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'No bills yet',
        message:
            'Add your rent, utilities, subscriptions, and other recurring payments to stay organized.',
        actionLabel: 'Add Bill',
        actionIcon: Icons.add_rounded,
        onAction: () => context.push('/app/bills/add'),
      );
    }
    if (state.filter == BillFilter.overdue) {
      return const EmptyState(
        icon: Icons.check_circle_rounded,
        title: 'No overdue bills',
        message: 'No overdue bills 🎉',
      );
    }
    if (state.filter == BillFilter.upcoming ||
        state.filter == BillFilter.dueToday) {
      return const EmptyState(
        icon: Icons.check_circle_rounded,
        title: "You're all clear!",
        message: 'No upcoming bills.',
      );
    }
    return EmptyState(
      icon: Icons.search_off_rounded,
      title: 'No results',
      message: 'No bills match your search or filter.',
    );
  }

  Future<void> _confirmMarkPaid(BuildContext context, BillEntity bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Paid?'),
        content: Text('Mark "${bill.title}" as paid?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Mark Paid'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<BillBloc>().add(BillMarkPaid(bill.id));
    }
  }
}

class _BillSummaryCards extends StatelessWidget {
  final BillState state;
  const _BillSummaryCards({required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: _SummaryTile(
              label: 'Upcoming',
              amount: state.upcomingTotal,
              color: AppColors.primary,
              icon: Icons.schedule_rounded,
              count: state.upcomingBills.length,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _SummaryTile(
              label: 'Due Today',
              amount: state.dueTodayTotal,
              color: AppColors.warning,
              icon: Icons.today_rounded,
              count: state.dueTodayBills.length,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _SummaryTile(
              label: 'Overdue',
              amount: state.overdueTotal,
              color: AppColors.error,
              icon: Icons.error_outline_rounded,
              count: state.overdueBills.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final int count;

  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.smd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          MoneyText(
            amount: amount,
            decimalDigits: 0,
            color: color,
            amountStyle: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$count ${count == 1 ? 'bill' : 'bills'}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillFilterChips extends StatelessWidget {
  final BillFilter currentFilter;
  final ValueChanged<BillFilter> onFilterChanged;

  const _BillFilterChips({
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: BillFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final filter = BillFilter.values[index];
          final isSelected = currentFilter == filter;
          return FilterChip(
            label: Text(filter.label),
            selected: isSelected,
            onSelected: (_) => onFilterChanged(filter),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}

class _BillsSkeleton extends StatelessWidget {
  const _BillsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SkeletonBox(width: 120, height: 32, radius: 12),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 100, radius: 16),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 48, radius: 16),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 64, radius: 16),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(height: 64, radius: 16),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(height: 64, radius: 16),
        ],
      ),
    );
  }
}

class _BillsErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _BillsErrorWidget({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
