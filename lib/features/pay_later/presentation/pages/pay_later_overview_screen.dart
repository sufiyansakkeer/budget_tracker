import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/navigation/push_unique.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_disclosure.dart';
import '../../../../core/widgets/app_fab.dart';
import '../../../../core/widgets/app_list.dart';
import '../../../../core/widgets/app_metric.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_notice.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/pay_later_overview.dart';
import '../../domain/entities/pay_later_tab.dart';
import '../../domain/entities/tab_ledger.dart';
import '../bloc/pay_later_overview_bloc.dart';
import '../bloc/pay_later_overview_event.dart';
import '../bloc/pay_later_overview_state.dart';
import '../widgets/pay_later_charts.dart';
import '../widgets/tab_tile.dart';
import '../widgets/tab_visuals.dart';

/// Pay later overview (spec §7): what is owed per currency, this month's
/// activity, every tab, recent purchases and payments, and the charts.
class PayLaterOverviewScreen extends StatefulWidget {
  const PayLaterOverviewScreen({super.key});

  /// How many recent purchases and payments show before "See all".
  static const recentCount = 5;

  @override
  State<PayLaterOverviewScreen> createState() => _PayLaterOverviewScreenState();
}

class _PayLaterOverviewScreenState extends State<PayLaterOverviewScreen> {
  bool _allPurchases = false;
  bool _allPayments = false;

  @override
  void initState() {
    super.initState();
    context.read<PayLaterOverviewBloc>().add(const PayLaterOverviewStarted());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PayLaterOverviewBloc, PayLaterOverviewState>(
      builder: (context, state) {
        final overview = state.overview;
        final Widget body;
        if (overview == null) {
          body = state.status == PayLaterOverviewStatus.error
              ? _LoadError(
                  key: const ValueKey('error'),
                  message:
                      state.errorMessage ??
                      PayLaterOverviewBloc.loadFailedMessage,
                )
              : const _OverviewSkeleton(key: ValueKey('loading'));
        } else if (overview.isEmpty) {
          body = EmptyState(
            key: const ValueKey('empty'),
            icon: Icons.receipt_long_rounded,
            title: 'No tabs yet',
            message:
                'A tab keeps track of what you owe a place that lets you pay '
                'later, like a cafeteria or a corner shop.',
            actionLabel: 'Create a tab',
            actionIcon: Icons.add_rounded,
            onAction: () => _newTab(context),
          );
        } else {
          body = KeyedSubtree(
            key: const ValueKey('content'),
            child: _content(context, state, overview),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Pay later')),
          body: AppStateSwitcher(child: body),
          floatingActionButton: overview == null || overview.isEmpty
              ? null
              : overview.activeTabCount == 0
              // Every tab is archived: nothing to add to, so the button says
              // what it does (an action keeps its name).
              ? AppFab(
                  heroTag: 'pay_later_fab',
                  onPressed: () => _newTab(context),
                  icon: Icons.add_rounded,
                  label: 'New tab',
                  tooltip: 'Create a tab',
                )
              : AppFab(
                  heroTag: 'pay_later_fab',
                  onPressed: () => _addToTab(context, overview),
                  icon: Icons.add_rounded,
                  label: 'Add to a tab',
                  tooltip: 'Add a purchase to a tab',
                ),
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    PayLaterOverviewState state,
    PayLaterOverview overview,
  ) {
    final listed = [
      for (final l in overview.tabs)
        if (!l.tab.isArchived || PayLaterOverview.hasBalance(l)) l,
    ];
    final archived = [
      for (final l in overview.tabs)
        if (l.tab.isArchived && !PayLaterOverview.hasBalance(l)) l,
    ];
    final archivedOwing = [
      for (final l in listed)
        if (l.tab.isArchived && l.owed > 0) l.tab.name,
    ];
    final archivedInCredit = [
      for (final l in listed)
        if (l.tab.isArchived && l.owed <= 0 && l.credit > 0) l.tab.name,
    ];
    final owing = [
      for (final l in overview.tabs)
        if (l.owed > 0) l,
    ];
    var index = 0;

    return ListView(
      padding: AppSpacing.pagePaddingWithFab,
      children: [
        if (overview.totals.isNotEmpty) ...[
          FadeSlideIn(
            index: index++,
            child: _Totals(overview: overview),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            if (owing.isNotEmpty)
              FilledButton.tonalIcon(
                key: const Key('payLaterRecordPaymentButton'),
                onPressed: () => _recordPayment(context, owing),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Record payment'),
              ),
            TextButton.icon(
              key: const Key('payLaterNewTabButton'),
              onPressed: () => _newTab(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New tab'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (archivedOwing.isNotEmpty || archivedInCredit.isNotEmpty) ...[
          AppNotice(
            tone: AppTone.caution,
            icon: Icons.inventory_2_outlined,
            title: 'Archived, has a balance',
            message: _archivedMessage(archivedOwing, archivedInCredit),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        FadeSlideIn(
          index: index++,
          child: AppSection(
            title: 'Tabs',
            subtitle: overview.activeTabCount == 1
                ? '1 active'
                : '${overview.activeTabCount} active',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (listed.isNotEmpty)
                  AppGroupedList(
                    dividerIndent: AppSizes.avatarSm + AppSpacing.smd,
                    children: [for (final l in listed) _tile(context, l)],
                  ),
                if (archived.isNotEmpty)
                  AppDisclosure(
                    title: 'Archived tabs',
                    summary: archived.length == 1
                        ? '1 tab with nothing owed'
                        : '${archived.length} tabs with nothing owed',
                    child: AppGroupedList(
                      dividerIndent: AppSizes.avatarSm + AppSpacing.smd,
                      children: [for (final l in archived) _tile(context, l)],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (overview.recentPurchases.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _recentPurchases(context, overview),
        ],
        if (overview.recentPayments.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _recentPayments(context, overview),
        ],
        if (state.currency != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _charts(context, state, overview),
        ],
      ],
    );
  }

  Widget _tile(BuildContext context, TabLedger ledger) => KeyedSubtree(
    key: Key('payLaterTab_${ledger.tab.id}'),
    child: TabTile(
      ledger: ledger,
      onTap: () => _openTab(context, ledger.tab.id),
    ),
  );

  Widget _recentPurchases(BuildContext context, PayLaterOverview overview) {
    final all = overview.recentPurchases;
    final shown = _allPurchases
        ? all
        : all.take(PayLaterOverviewScreen.recentCount).toList();
    return AppSection(
      title: 'Recent purchases',
      action: all.length > PayLaterOverviewScreen.recentCount
          ? TextButton(
              key: const Key('recentPurchasesSeeAll'),
              onPressed: () => setState(() => _allPurchases = !_allPurchases),
              child: Text(_allPurchases ? 'Show less' : 'See all'),
            )
          : null,
      child: AppGroupedList(
        children: [
          for (final line in shown)
            _purchaseRow(
              context,
              line,
              overview.tabForPurchase(line.expense.id),
              overview.today,
            ),
        ],
      ),
    );
  }

  Widget _purchaseRow(
    BuildContext context,
    PurchaseLine line,
    PayLaterTab? tab,
    DateTime today,
  ) {
    final expense = line.expense;
    final status = switch (line.status) {
      PurchaseStatus.paid => 'Paid',
      PurchaseStatus.partlyPaid => 'Partly paid',
      PurchaseStatus.unpaid => 'Unpaid',
    };
    final note = expense.note?.trim();
    return AppListRow(
      key: Key('recentPurchase_${expense.id}'),
      title: tab?.name ?? 'Tab',
      subtitle: [
        TabTile.formatDay(expense.date, today: today),
        if (note != null && note.isNotEmpty) note,
        status,
      ].join(' · '),
      trailing: AppMoney(
        amount: expense.amount,
        currency: tab?.currency,
        textAlign: TextAlign.end,
      ),
      onTap: () => context.pushUnique('/app/expenses/${expense.id}'),
    );
  }

  Widget _recentPayments(BuildContext context, PayLaterOverview overview) {
    final all = overview.recentPayments;
    final shown = _allPayments
        ? all
        : all.take(PayLaterOverviewScreen.recentCount).toList();
    return AppSection(
      title: 'Recent payments',
      action: all.length > PayLaterOverviewScreen.recentCount
          ? TextButton(
              key: const Key('recentPaymentsSeeAll'),
              onPressed: () => setState(() => _allPayments = !_allPayments),
              child: Text(_allPayments ? 'Show less' : 'See all'),
            )
          : null,
      child: AppGroupedList(
        children: [
          for (final line in shown)
            _paymentRow(
              context,
              line,
              overview.tabForPayment(line),
              overview.today,
            ),
        ],
      ),
    );
  }

  Widget _paymentRow(
    BuildContext context,
    PaymentLine line,
    PayLaterTab? tab,
    DateTime today,
  ) {
    final payment = line.payment;
    final note = payment.note?.trim();
    return AppListRow(
      key: Key('recentPayment_${payment.id}'),
      title: tab?.name ?? 'Tab',
      subtitle: [
        'Paid ${TabTile.formatDay(payment.paidDate, today: today)}',
        if (note != null && note.isNotEmpty) note,
      ].join(' · '),
      trailing: AppMoney(
        amount: payment.amount,
        currency: tab?.currency,
        textAlign: TextAlign.end,
      ),
      onTap: () => _openTab(context, payment.tabId),
    );
  }

  Widget _charts(
    BuildContext context,
    PayLaterOverviewState state,
    PayLaterOverview overview,
  ) {
    final theme = Theme.of(context);
    final analytics = state.analytics;
    final Widget charts;
    if (analytics != null) {
      charts = PayLaterCharts(
        key: ValueKey('charts_${analytics.currency}'),
        analytics: analytics,
      );
    } else if (state.analyticsStatus == PayLaterAnalyticsStatus.error) {
      charts = StatusCard(
        key: const ValueKey('chartsError'),
        color: theme.colorScheme.error,
        icon: Icons.error_outline_rounded,
        message: "Couldn't load the charts.",
        trailing: TextButton(
          onPressed: () => context.read<PayLaterOverviewBloc>().add(
            const PayLaterOverviewRefreshed(),
          ),
          child: const Text('Try again'),
        ),
      );
    } else {
      charts = const Shimmer(
        key: ValueKey('chartsLoading'),
        child: SkeletonBox(
          height: AppSizes.chartHeight,
          radius: AppSpacing.radiusMd,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (overview.totals.length > 1) ...[
          Wrap(
            key: const Key('payLaterCurrencySwitcher'),
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final totals in overview.totals)
                ChoiceChip(
                  key: Key('payLaterCurrency_${totals.currency}'),
                  label: Text(totals.currency),
                  selected: totals.currency == state.currency,
                  showCheckmark: false,
                  onSelected: (_) => context.read<PayLaterOverviewBloc>().add(
                    PayLaterOverviewCurrencySelected(totals.currency),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        AppStateSwitcher(child: charts),
      ],
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────

  void _newTab(BuildContext context) =>
      context.pushUnique('${AppRouter.payLaterPath}/new');

  void _openTab(BuildContext context, String tabId) =>
      context.pushUnique('${AppRouter.payLaterPath}/$tabId');

  /// One active tab: straight to the expense form on it. Several: asks
  /// which first. (With none, the button is "New tab" instead.)
  Future<void> _addToTab(
    BuildContext context,
    PayLaterOverview overview,
  ) async {
    final active = [
      for (final l in overview.tabs)
        if (!l.tab.isArchived) l,
    ];
    if (active.isEmpty) return;
    final tabId = active.length == 1
        ? active.single.tab.id
        : await _pickTab(context, title: 'Add to which tab?', tabs: active);
    if (tabId == null || !context.mounted) return;
    context.pushUnique('/app/expenses/add?tab=$tabId');
  }

  /// The payment sheet lives on the tab's screen: one tab owing opens it,
  /// several ask which first.
  Future<void> _recordPayment(
    BuildContext context,
    List<TabLedger> owing,
  ) async {
    final tabId = owing.length == 1
        ? owing.single.tab.id
        : await _pickTab(
            context,
            title: 'Pay which tab?',
            tabs: owing,
            showOwed: true,
          );
    if (tabId == null || !context.mounted) return;
    _openTab(context, tabId);
  }

  Future<String?> _pickTab(
    BuildContext context, {
    required String title,
    required List<TabLedger> tabs,
    bool showOwed = false,
  }) {
    final theme = Theme.of(context);
    return AppBottomSheet.show<String>(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSheetHeader(title: title),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                for (final l in tabs)
                  AppListRow(
                    key: Key('pickTab_${l.tab.id}'),
                    leading: IconTile(
                      icon: tabCategoryIcon(l.tab.category),
                      color: theme.colorScheme.primary,
                      size: AppSizes.avatarSm,
                    ),
                    title: l.tab.name,
                    subtitle: showOwed
                        ? 'Owes ${AppMoney.format(l.owed, currency: l.tab.currency)}'
                        : l.tab.currency,
                    onTap: () => Navigator.of(sheetContext).pop(l.tab.id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  /// Owing tabs count in the totals; tabs only in credit don't (the totals
  /// hold what is owed), so each group gets its own true sentence.
  static String _archivedMessage(List<String> owing, List<String> inCredit) {
    final one = owing.length == 1;
    return [
      if (owing.isNotEmpty)
        '${_names(owing)} ${one ? 'is' : 'are'} archived but still '
            '${one ? 'owes' : 'owe'} money. ${one ? 'It counts' : 'They count'} '
            'in your totals until settled.',
      if (inCredit.isNotEmpty)
        inCredit.length == 1
            ? '${inCredit.single} is archived but holds credit, so it stays '
                  'listed here.'
            : '${_names(inCredit)} are archived but hold credit, so they '
                  'stay listed here.',
    ].join(' ');
  }

  static String _names(List<String> names) => switch (names.length) {
    1 => names.single,
    2 => '${names[0]} and ${names[1]}',
    _ => '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}',
  };
}

/// What is owed in each currency, with overdue, the next settle-up day and
/// this month's activity. One block per currency: never summed across.
class _Totals extends StatelessWidget {
  final PayLaterOverview overview;

  const _Totals({required this.overview});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final several = overview.totals.length > 1;
    return Column(
      key: const Key('payLaterTotals'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < overview.totals.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.smd),
          _block(theme, overview.totals[i], several),
        ],
      ],
    );
  }

  Widget _block(ThemeData theme, CurrencyTotals totals, bool several) {
    final code = totals.currency;
    final next = overview.upcoming
        .where((u) => u.$1.currency == code)
        .firstOrNull;
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppMetric(
            label: several ? 'Owed in $code' : 'Owed',
            value: AppMoney(
              amount: totals.owed,
              currency: code,
              role: MoneyRole.display,
            ),
          ),
          if (totals.overdue > 0 || next != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (totals.overdue > 0)
                  StatusChip.tone(
                    label:
                        '${AppMoney.format(totals.overdue, currency: code)} '
                        'overdue',
                    tone: AppTone.critical,
                    icon: Icons.schedule_rounded,
                    wrapLabel: true,
                  ),
                if (next != null)
                  Text(
                    'Next settle-up '
                    '${TabTile.relativeDay(next.$2, today: overview.today)} · '
                    '${next.$1.name}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppMetric(
                  label: 'Added this month',
                  value: AppMoney(
                    amount: totals.addedThisMonth,
                    currency: code,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppMetric(
                  label: 'Paid this month',
                  alignEnd: true,
                  value: AppMoney(
                    amount: totals.paidThisMonth,
                    currency: code,
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The first load failed: a real error, with a way to try again.
class _LoadError extends StatelessWidget {
  final String message;

  const _LoadError({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: AppSpacing.pagePadding,
      children: [
        StatusCard(
          color: theme.colorScheme.error,
          icon: Icons.error_outline_rounded,
          title: "Couldn't load your tabs.",
          message: message,
          trailing: TextButton(
            onPressed: () => context.read<PayLaterOverviewBloc>().add(
              const PayLaterOverviewStarted(),
            ),
            child: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}

class _OverviewSkeleton extends StatelessWidget {
  const _OverviewSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Loading your tabs',
      excludeSemantics: true,
      child: Shimmer(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: AppSpacing.pagePadding,
          children: [
            const SkeletonBox(height: 140, radius: AppSpacing.radiusLg),
            const SizedBox(height: AppSpacing.lg),
            SkeletonText(style: theme.textTheme.titleMedium, width: 120),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < 3; i++)
              const SkeletonListTile(leadingSize: AppSizes.avatarSm),
          ],
        ),
      ),
    );
  }
}
