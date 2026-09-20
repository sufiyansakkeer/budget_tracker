import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../domain/entities/bill_entity.dart';
import '../../domain/entities/bill_enums.dart';
import '../bloc/bill_bloc.dart';
import '../bloc/bill_event.dart';
import '../bloc/bill_state.dart';
import 'bill_widgets.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/widgets/animated_amount.dart';
import '../../../../core/widgets/app_fab.dart';

/// Bills & reminders: what is due next, totals by status, and the full list.
class BillsListScreen extends StatefulWidget {
  const BillsListScreen({super.key});

  @override
  State<BillsListScreen> createState() => _BillsListScreenState();
}

class _BillsListScreenState extends State<BillsListScreen> {
  final TextEditingController _searchController = TextEditingController();

  static const _info = InfoContent(
    title: 'Bills & Reminders',
    whatIsThis:
        'Payments you want to remember, such as rent, utilities or '
        'subscriptions. Bills are kept separately from your budgets and are '
        'shared across all of them.',
    howIsItCalculated:
        "A bill's status comes from its due date and whether it is paid:\n"
        'Upcoming: unpaid and due after today.\n'
        'Due today: unpaid and due today.\n'
        'Overdue: unpaid and due before today.\n'
        'Paid: marked as paid.\n\n'
        'The summary tiles add up the unpaid amounts in each status.',
    additionalNotes:
        '• A bill due today is not overdue; it becomes overdue from the next '
        'day\n'
        '• Marking a one-time bill as paid moves it to Paid. Marking a '
        'recurring bill as paid moves its due date to the next occurrence\n'
        '• A bill only affects a budget if you use "Mark paid & add expense", '
        'which records it as an expense in your active budget\n'
        '• Reminders are optional per bill: a notification on the due date or '
        'a set number of days before. Notifications must be allowed on your '
        'device',
  );

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

  Future<void> _refresh() async {
    final bloc = context.read<BillBloc>();
    final done = bloc.stream
        .firstWhere(
          (s) =>
              s.status == BillBlocStatus.loaded ||
              s.status == BillBlocStatus.error,
        )
        .timeout(const Duration(seconds: 8), onTimeout: () => bloc.state);
    bloc.add(const BillRefresh());
    await done;
  }

  Future<void> _confirmMarkPaid(BillEntity bill) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Mark as paid?',
      message: bill.isRecurring
          ? '"${bill.title}" will be marked paid and its due date moves to '
                'the next ${bill.recurrenceType.label.toLowerCase()} '
                'occurrence.'
          : '"${bill.title}" will be marked as paid.',
      confirmLabel: 'Mark paid',
      icon: Icons.check_circle_rounded,
    );
    if (confirmed && mounted) {
      context.read<BillBloc>().add(BillMarkPaid(bill.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bills'),
        actions: [InfoIcon(content: _info)],
      ),
      body: BlocConsumer<BillBloc, BillState>(
        listenWhen: (prev, curr) =>
            prev.status != curr.status &&
            (curr.status == BillBlocStatus.success ||
                curr.status == BillBlocStatus.error) &&
            curr.message != null,
        listener: (context, state) {
          // Only surface messages while the list is visible (the error view
          // handles the empty-and-failed case itself).
          if (state.status == BillBlocStatus.error && state.allBills.isEmpty) {
            return;
          }
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.message!)));
          context.read<BillBloc>().add(const BillClearMessage());
        },
        builder: (context, state) {
          final Widget child;
          if (state.status == BillBlocStatus.loading &&
              state.allBills.isEmpty) {
            child = const _BillsSkeleton(key: ValueKey('loading'));
          } else if (state.status == BillBlocStatus.error &&
              state.allBills.isEmpty) {
            child = ErrorState(
              key: const ValueKey('error'),
              title: "Couldn't load your bills",
              message: state.message ?? 'Please try again.',
              onRetry: () => context.read<BillBloc>().add(const BillRefresh()),
            );
          } else if (state.allBills.isEmpty) {
            child = EmptyState(
              key: const ValueKey('empty'),
              icon: Icons.receipt_long_rounded,
              title: 'No bills yet',
              message:
                  'Add rent, utilities, subscriptions and other payments to '
                  'get reminded before they are due.',
              actionLabel: 'Add bill',
              actionIcon: Icons.add_rounded,
              onAction: () => context.push('/app/bills/add'),
            );
          } else {
            child = _buildContent(context, state);
          }
          return AppStateSwitcher(child: child);
        },
      ),
      floatingActionButton: AppFab(
        heroTag: 'bills_fab',
        onPressed: () => context.push('/app/bills/add'),
        icon: Icons.add_rounded,
        label: 'Add bill',
        tooltip: 'Add a new bill',
      ),
    );
  }

  Widget _buildContent(BuildContext context, BillState state) {
    final filtered = state.filteredBills;
    final unpaid = state.allBills.where((b) => !b.isPaid).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final nextUp = unpaid.isEmpty ? null : unpaid.first;
    var index = 0;

    return RefreshIndicator(
      key: const ValueKey('content'),
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.pagePaddingWithFab,
        children: [
          if (nextUp != null) ...[
            FadeSlideIn(
              index: index++,
              // When the next bill changes (e.g. one was just paid) the
              // card cross-fades to the new one.
              child: AnimatedSwitcher(
                duration: AppMotion.respectReducedMotion(
                  context,
                  AppMotion.medium,
                ),
                switchInCurve: AppMotion.enter,
                switchOutCurve: AppMotion.exit,
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.passthrough,
                  alignment: Alignment.topCenter,
                  children: [...previous, if (current != null) current],
                ),
                child: _NextUpCard(key: ValueKey(nextUp.id), bill: nextUp),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          FadeSlideIn(
            index: index++,
            child: _SummaryRow(state: state),
          ),
          const SizedBox(height: AppSpacing.lg),

          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search bills',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, _) => value.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          context.read<BillBloc>().add(
                            const BillSearchChanged(''),
                          );
                        },
                      ),
              ),
            ),
            onChanged: (query) =>
                context.read<BillBloc>().add(BillSearchChanged(query)),
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final filter in BillFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: FilterChip(
                      label: Text(filter.label),
                      selected: state.filter == filter,
                      onSelected: (_) => context.read<BillBloc>().add(
                        BillFilterChanged(filter),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          if (filtered.isEmpty)
            _buildEmptyFilter(context, state)
          else if (state.filter == BillFilter.all)
            ..._grouped(context, filtered, index)
          else
            for (final bill in filtered)
              FadeSlideIn(
                key: ValueKey('bill_${bill.id}'),
                index: index++,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _card(context, bill),
                ),
              ),
        ],
      ),
    );
  }

  List<Widget> _grouped(
    BuildContext context,
    List<BillEntity> bills,
    int index,
  ) {
    const order = [
      (BillStatus.overdue, 'Overdue'),
      (BillStatus.dueToday, 'Due today'),
      (BillStatus.upcoming, 'Upcoming'),
      (BillStatus.paid, 'Paid'),
    ];
    final widgets = <Widget>[];
    for (final (status, title) in order) {
      final group = bills.where((b) => b.status == status).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      if (group.isEmpty) continue;
      widgets.add(SectionHeader(title: title));
      for (final bill in group) {
        widgets.add(
          FadeSlideIn(
            key: ValueKey('bill_${bill.id}'),
            index: index++,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _card(context, bill),
            ),
          ),
        );
      }
      widgets.add(const SizedBox(height: AppSpacing.sm));
    }
    return widgets;
  }

  Widget _card(BuildContext context, BillEntity bill) {
    return BillCard(
      bill: bill,
      onTap: () => context.push('/app/bills/${bill.id}'),
      onMarkPaid: bill.isPaid ? null : () => _confirmMarkPaid(bill),
    );
  }

  Widget _buildEmptyFilter(BuildContext context, BillState state) {
    if (state.searchQuery.trim().isNotEmpty) {
      return EmptyState.compact(
        icon: Icons.search_off_rounded,
        title: 'No matching bills',
        message: 'Nothing matches "${state.searchQuery.trim()}".',
        actionLabel: 'Clear search',
        actionIcon: Icons.clear_all_rounded,
        onAction: () {
          _searchController.clear();
          context.read<BillBloc>().add(const BillSearchChanged(''));
        },
      );
    }
    final (icon, title, message) = switch (state.filter) {
      BillFilter.overdue => (
        Icons.check_circle_rounded,
        'Nothing overdue',
        'Every bill is paid or still ahead of its due date.',
      ),
      BillFilter.dueToday => (
        Icons.event_available_rounded,
        'Nothing due today',
        'No unpaid bills are due today.',
      ),
      BillFilter.upcoming => (
        Icons.event_available_rounded,
        'Nothing coming up',
        'No unpaid bills are due after today.',
      ),
      BillFilter.paid => (
        Icons.receipt_long_outlined,
        'No paid bills yet',
        'Bills you mark as paid appear here.',
      ),
      BillFilter.recurring => (
        Icons.repeat_rounded,
        'No recurring bills',
        'Turn on "Repeat" when adding a bill to see it here.',
      ),
      BillFilter.all => (
        Icons.receipt_long_outlined,
        'No bills',
        'Add a bill to get started.',
      ),
    };
    return EmptyState.compact(icon: icon, title: title, message: message);
  }
}

/// The single most important bill: the earliest unpaid one.
class _NextUpCard extends StatelessWidget {
  final BillEntity bill;
  const _NextUpCard({super.key, required this.bill});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = bill.status;
    final color = BillVisuals.colorFor(context, status);
    return AppCard(
      onTap: () => context.push('/app/bills/${bill.id}'),
      color: color.withValues(alpha: 0.08),
      showBorder: false,
      child: Row(
        children: [
          IconTile(
            icon: BillVisuals.statusIcon(status),
            color: color,
            circular: true,
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status == BillStatus.overdue ? 'Needs attention' : 'Next up',
                  style: theme.textTheme.labelMedium?.copyWith(color: color),
                ),
                Text(
                  bill.title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  BillVisuals.dueText(bill),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            CurrencyFormatter.format(
              bill.amount,
              code: bill.currency,
              decimalDigits: 0,
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final BillState state;
  const _SummaryRow({required this.state});

  @override
  Widget build(BuildContext context) {
    double sum(Iterable<BillEntity> bills) =>
        bills.fold(0.0, (s, b) => s + b.amount);
    final overdue = state.overdueBills;
    final dueToday = state.dueTodayBills;
    final upcoming = state.upcomingBills;
    final currency = state.allBills.isNotEmpty
        ? state.allBills.first.currency
        : '';

    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            status: BillStatus.overdue,
            amount: sum(overdue),
            count: overdue.length,
            currency: currency,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _SummaryTile(
            status: BillStatus.dueToday,
            amount: sum(dueToday),
            count: dueToday.length,
            currency: currency,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _SummaryTile(
            status: BillStatus.upcoming,
            amount: sum(upcoming),
            count: upcoming.length,
            currency: currency,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final BillStatus status;
  final double amount;
  final int count;
  final String currency;

  const _SummaryTile({
    required this.status,
    required this.amount,
    required this.count,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = BillVisuals.colorFor(context, status);
    final label = BillVisuals.statusLabel(status);
    return Semantics(
      label:
          '$label: $count ${count == 1 ? 'bill' : 'bills'}, '
          '${CurrencyFormatter.format(amount, code: currency, decimalDigits: 0)}',
      child: ExcludeSemantics(
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.smd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    BillVisuals.statusIcon(status),
                    size: AppSizes.iconSm,
                    color: color,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              AnimatedAmount(
                amount: amount,
                currency: currency,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '$count ${count == 1 ? 'bill' : 'bills'}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillsSkeleton extends StatelessWidget {
  const _BillsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: AppSpacing.pagePadding,
        children: const [
          SkeletonBox(height: 84, radius: AppSpacing.radiusLg),
          SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SkeletonBox(height: 88, radius: AppSpacing.radiusLg),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SkeletonBox(height: 88, radius: AppSpacing.radiusLg),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SkeletonBox(height: 88, radius: AppSpacing.radiusLg),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(height: 48, radius: AppSpacing.radiusMd),
          SizedBox(height: AppSpacing.md),
          SkeletonListTile(),
          SkeletonListTile(),
          SkeletonListTile(),
        ],
      ),
    );
  }
}
