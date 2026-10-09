import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/events/refresh_bus.dart';
import '../../../../core/widgets/app_list.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../budget/domain/usecases/manage_budget_usecase.dart';
import '../../domain/entities/bill_entity.dart';
import '../../domain/entities/bill_enums.dart';
import '../bloc/bill_bloc.dart';
import '../bloc/bill_event.dart';
import '../bloc/bill_state.dart';
import 'bill_budget_link.dart';
import 'bill_payment_dialogs.dart';
import 'bill_widgets.dart';
import '../../../../core/widgets/app_fab.dart';
import '../../../../core/navigation/push_unique.dart';

/// Bills & reminders as one list: overdue, due soon (the next
/// [BillVisuals.dueSoonDays] days), later and paid. Each group says how many
/// and what they add up to per currency, so amounts in different currencies
/// are never summed.
class BillsListScreen extends StatefulWidget {
  const BillsListScreen({super.key});

  @override
  State<BillsListScreen> createState() => _BillsListScreenState();
}

class _BillsListScreenState extends State<BillsListScreen> {
  final TextEditingController _searchController = TextEditingController();

  static const _info = InfoContent(
    title: 'Bills & reminders',
    whatIsThis:
        'Payments you want to remember, such as rent, utilities or '
        'subscriptions. Link a bill to a budget and its amount is set aside '
        "from that budget until it's paid.",
    howIsItCalculated:
        "A bill's status comes from its due date and whether it is paid:\n"
        'Upcoming: unpaid and due after today.\n'
        'Due today: unpaid and due today.\n'
        'Overdue: unpaid and due before today.\n'
        'Paid: marked as paid.\n\n'
        'Overdue, Due soon (the next 7 days) and Later each show the unpaid '
        'total per currency.',
    additionalNotes:
        '• A bill due today is not overdue; it becomes overdue from the next '
        'day\n'
        '• Marking a one-time bill as paid moves it to Paid. Marking a '
        'recurring bill as paid moves its due date to the next occurrence\n'
        '• Bills linked to a budget are set aside from it until paid, so '
        "Today's Safe Spending already leaves room for them. "
        '"Mark paid & record expense" records the payment in that budget\n'
        "• Bills that aren't linked don't affect any budget. Use the "
        '"Not linked" filter to find them\n'
        '• Reminders are optional per bill: a notification on the due date or '
        'a set number of days before. Notifications must be allowed on your '
        'device',
  );

  Map<String, BudgetEntity> _budgetsById = const {};
  StreamSubscription<void>? _budgetSubscription;

  @override
  void initState() {
    super.initState();
    context.read<BillBloc>().add(const BillLoadAll());
    _loadBudgets();
    _budgetSubscription = RefreshBuses.budgets.changes.listen((_) {
      if (mounted) _loadBudgets();
    });
  }

  @override
  void dispose() {
    _budgetSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Budget names for the cards' "Paid from" line. A failure only hides
  /// that line.
  Future<void> _loadBudgets() async {
    try {
      final budgets = await getIt<ManageBudgetUseCase>().getAll();
      if (!mounted) return;
      setState(() => _budgetsById = {for (final b in budgets) b.id: b});
    } catch (_) {
      // Keep what we had.
    }
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
              message:
                  'Your bills are still on this device. Try again in a '
                  'moment.',
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
              onAction: () => context.pushUnique('/app/bills/add'),
            );
          } else {
            child = _buildContent(context, state);
          }
          return AppStateSwitcher(child: child);
        },
      ),
      floatingActionButton: AppFab(
        heroTag: 'bills_fab',
        onPressed: () => context.pushUnique('/app/bills/add'),
        icon: Icons.add_rounded,
        label: 'Add bill',
        tooltip: 'Add a new bill',
      ),
    );
  }

  Widget _buildContent(BuildContext context, BillState state) {
    final filtered = state.filteredBills;
    var index = 0;

    return RefreshIndicator(
      key: const ValueKey('content'),
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.pagePaddingWithFab,
        children: [
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
                      showCheckmark: false,
                      onSelected: (_) => context.read<BillBloc>().add(
                        BillFilterChanged(filter),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          if (filtered.isEmpty)
            _buildEmptyFilter(context, state)
          else if (state.filter == BillFilter.all)
            for (final section in _sections(filtered)) ...[
              FadeSlideIn(
                key: ValueKey('section_${section.title}'),
                index: index++,
                child: AppSection(
                  title: section.title,
                  subtitle: section.summary,
                  child: AppGroupedList(
                    dividerIndent: AppSizes.avatarSm + AppSpacing.smd,
                    children: [
                      for (final bill in section.bills)
                        KeyedSubtree(
                          key: ValueKey('bill_${bill.id}'),
                          child: _card(context, bill),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ]
          else
            FadeSlideIn(
              index: index++,
              child: AppSection(
                title: state.filter.label,
                subtitle: _summary(filtered, unpaidOnly: false),
                child: AppGroupedList(
                  dividerIndent: AppSizes.avatarSm + AppSpacing.smd,
                  children: [
                    for (final bill in filtered)
                      KeyedSubtree(
                        key: ValueKey('bill_${bill.id}'),
                        child: _card(context, bill),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Overdue, due soon (within [BillVisuals.dueSoonDays]), later and paid,
  /// each in due-date order. Empty sections are left out.
  List<_BillSection> _sections(List<BillEntity> bills) {
    final now = DateTime.now();
    List<BillEntity> sorted(Iterable<BillEntity> list) =>
        list.toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final overdue = sorted(bills.where((b) => b.status == BillStatus.overdue));
    final soon = sorted(bills.where((b) => BillVisuals.isDueSoon(b, now)));
    final later = sorted(
      bills.where(
        (b) =>
            !b.isPaid &&
            b.status != BillStatus.overdue &&
            !BillVisuals.isDueSoon(b, now),
      ),
    );
    final paid = bills.where((b) => b.isPaid).toList()
      ..sort(
        (a, b) => (b.paidDate ?? b.dueDate).compareTo(a.paidDate ?? a.dueDate),
      );
    return [
      if (overdue.isNotEmpty)
        _BillSection('Overdue', overdue, _summary(overdue)),
      if (soon.isNotEmpty) _BillSection('Due soon', soon, _summary(soon)),
      if (later.isNotEmpty) _BillSection('Later', later, _summary(later)),
      if (paid.isNotEmpty) _BillSection('Paid', paid, _count(paid.length)),
    ];
  }

  static String _count(int n) => '$n ${n == 1 ? 'bill' : 'bills'}';

  /// "2 bills · ₹2,499" or, across currencies, "3 bills · ₹2,499 · OMR 12":
  /// one total per currency, never added together.
  static String _summary(List<BillEntity> bills, {bool unpaidOnly = true}) {
    final counted = unpaidOnly ? bills.where((b) => !b.isPaid) : bills;
    final totals = BillVisuals.totalsByCurrency(counted);
    return [
      _count(bills.length),
      for (final MapEntry(key: code, value: amount) in totals.entries)
        AppMoney.format(amount, currency: code),
    ].join(' · ');
  }

  Widget _card(BuildContext context, BillEntity bill) {
    final budget = bill.budgetId == null ? null : _budgetsById[bill.budgetId];
    // A linked bill's quick action records the payment in its budget; a
    // plain "paid" would release the money set aside without spending it.
    final linked = bill.budgetId != null;
    return BillCard(
      bill: bill,
      onTap: () => context.pushUnique('/app/bills/${bill.id}'),
      onMarkPaid: bill.isPaid
          ? null
          : linked
          ? () => BillPaymentDialogs.payWithExpense(context, bill)
          : () => BillPaymentDialogs.markPaid(context, bill),
      markPaidLabel: linked ? 'Mark paid & record expense' : 'Mark as paid',
      showBudgetLink: true,
      budgetName: budget == null
          ? null
          : BillBudgetLink.budgetLabel(budget, DateTime.now()),
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
      BillFilter.notLinked => (
        Icons.link_rounded,
        'Every bill is linked',
        'Each bill has a budget it is paid from.',
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

/// One group of the bills list.
class _BillSection {
  final String title;
  final List<BillEntity> bills;

  /// Count and per-currency totals, under the title.
  final String summary;

  const _BillSection(this.title, this.bills, this.summary);
}

class _BillsSkeleton extends StatelessWidget {
  const _BillsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: AppSpacing.pagePadding,
        children: [
          const SkeletonBox(height: 48, radius: AppSpacing.radiusSm),
          const SizedBox(height: AppSpacing.lg),
          SkeletonText(style: theme.textTheme.titleMedium, width: 120),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < 3; i++)
            const SkeletonListTile(leadingSize: AppSizes.avatarSm),
        ],
      ),
    );
  }
}
