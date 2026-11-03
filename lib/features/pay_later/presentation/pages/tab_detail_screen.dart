import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/money_math.dart';
import '../../../../core/dates/calendar_dates.dart';
import '../../../../core/navigation/push_unique.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_list.dart';
import '../../../../core/widgets/app_metric.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_notice.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../../../expenses/presentation/widgets/category_visuals.dart';
import '../../domain/entities/settle_rhythm.dart';
import '../../domain/entities/tab_ledger.dart';
import '../bloc/tab_detail_bloc.dart';
import '../bloc/tab_detail_event.dart';
import '../bloc/tab_detail_state.dart';
import '../widgets/payment_history_tile.dart';
import '../widgets/payment_sheet.dart';
import '../widgets/period_group.dart';
import '../widgets/tab_tile.dart';
import '../widgets/tab_visuals.dart';

enum _Segment { purchases, payments }

enum _MenuAction { archive, unarchive, delete }

/// One tab (spec §7 "Tab detail"): what it owes, overdue, the next
/// settle-up, totals, the actions on it, its purchases by period, its
/// payments and a breakdown by expense category.
class TabDetailScreen extends StatefulWidget {
  final String tabId;

  const TabDetailScreen({super.key, required this.tabId});

  @override
  State<TabDetailScreen> createState() => _TabDetailScreenState();
}

class _TabDetailScreenState extends State<TabDetailScreen> {
  _Segment _segment = _Segment.purchases;

  TabDetailBloc get _bloc => context.read<TabDetailBloc>();

  DateTime get _today => _bloc.clock().dateOnly;

  @override
  void initState() {
    super.initState();
    context.read<TabDetailBloc>().add(TabDetailStarted(widget.tabId));
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRouter.payLaterPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TabDetailBloc, TabDetailState>(
      listenWhen: (previous, current) =>
          previous.messageId != current.messageId,
      listener: (context, state) {
        final message = state.message;
        if (message != null) _show(message);
        if (state.deleted) _close();
      },
      builder: (context, state) {
        final ledger = state.ledger;
        final Widget body;
        if (state.status == TabDetailStatus.notFound) {
          body = EmptyState(
            key: const ValueKey('missing'),
            icon: Icons.receipt_long_outlined,
            title: 'Tab not found',
            message: 'It may have been deleted.',
            actionLabel: 'Back to Pay later',
            actionIcon: Icons.arrow_back_rounded,
            onAction: _close,
          );
        } else if (ledger == null) {
          body = state.status == TabDetailStatus.error
              ? _LoadError(
                  key: const ValueKey('error'),
                  message:
                      state.errorMessage ?? TabDetailBloc.loadFailedMessage,
                  onRetry: () => _bloc.add(TabDetailStarted(widget.tabId)),
                )
              : const FormSkeleton(key: ValueKey('loading'), rows: 4);
        } else {
          body = KeyedSubtree(
            key: const ValueKey('content'),
            child: _content(context, state, ledger),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(ledger?.tab.name ?? 'Tab'),
            actions: [
              if (ledger != null &&
                  state.status != TabDetailStatus.notFound) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit tab',
                  onPressed: state.busy ? null : () => _edit(ledger),
                ),
                _menu(state, ledger),
              ],
            ],
          ),
          body: AppStateSwitcher(child: body),
        );
      },
    );
  }

  Widget _menu(TabDetailState state, TabLedger ledger) {
    final unused = ledger.purchases.isEmpty && ledger.payments.isEmpty;
    return PopupMenuButton<_MenuAction>(
      key: const Key('tabMoreMenu'),
      tooltip: 'More',
      enabled: !state.busy,
      onSelected: (action) => switch (action) {
        _MenuAction.archive => _archive(ledger),
        _MenuAction.unarchive => _bloc.add(const TabDetailUnarchiveRequested()),
        _MenuAction.delete => _deleteTab(ledger),
      },
      itemBuilder: (_) => [
        if (ledger.tab.isArchived)
          const PopupMenuItem(
            value: _MenuAction.unarchive,
            child: Text('Unarchive'),
          )
        else
          const PopupMenuItem(
            value: _MenuAction.archive,
            child: Text('Archive'),
          ),
        // A used tab is archived instead: its history stays.
        if (unused)
          const PopupMenuItem(
            value: _MenuAction.delete,
            child: Text('Delete tab'),
          ),
      ],
    );
  }

  Widget _content(
    BuildContext context,
    TabDetailState state,
    TabLedger ledger,
  ) {
    final tab = ledger.tab;
    final today = _today;
    final owes = ledger.owed > 0;
    final busy = state.busy;
    return ListView(
      padding: AppSpacing.pagePadding,
      children: [
        if (ledger.needsSettleDate) ...[
          AppNotice(
            tone: AppTone.caution,
            icon: Icons.event_outlined,
            title: 'Set your next settle-up date',
            message:
                'The last settle-up date has passed. Purchases since then '
                "aren't part of any settle-up until you pick the next date.",
            action: TextButton(
              onPressed: () => _edit(ledger),
              child: const Text('Set date'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (tab.isArchived) ...[
          AppNotice(
            tone: AppTone.info,
            icon: Icons.inventory_2_outlined,
            title: 'Archived',
            message: owes
                ? 'This tab is archived but still owes money. It counts in '
                      'your totals until settled.'
                : ledger.credit > 0
                ? 'This tab is archived but holds credit.'
                : "Archived tabs can't take new purchases. Unarchive it to "
                      'add to it.',
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        _Header(ledger: ledger, today: today),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            if (owes)
              FilledButton.icon(
                key: const Key('tabRecordPaymentButton'),
                onPressed: busy ? null : () => _recordPayment(state, ledger),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Record payment'),
              ),
            if (owes)
              FilledButton.tonalIcon(
                key: const Key('tabSettleAllButton'),
                onPressed: busy
                    ? null
                    : () => _recordPayment(state, ledger, settleAll: true),
                icon: const Icon(Icons.done_all_rounded),
                label: const Text('Settle all'),
              ),
            // Archived tabs can't take new purchases.
            if (!tab.isArchived)
              OutlinedButton.icon(
                key: const Key('tabAddButton'),
                onPressed: busy
                    ? null
                    : () =>
                          context.pushUnique('/app/expenses/add?tab=${tab.id}'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add to tab'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SegmentedButton<_Segment>(
          segments: const [
            ButtonSegment(
              value: _Segment.purchases,
              label: Text('Purchases'),
              icon: Icon(Icons.receipt_long_outlined),
            ),
            ButtonSegment(
              value: _Segment.payments,
              label: Text('Payments'),
              icon: Icon(Icons.payments_outlined),
            ),
          ],
          selected: {_segment},
          showSelectedIcon: false,
          onSelectionChanged: (selected) =>
              setState(() => _segment = selected.single),
        ),
        const SizedBox(height: AppSpacing.md),
        AppStateSwitcher(
          child: KeyedSubtree(
            key: ValueKey(_segment),
            child: _segment == _Segment.purchases
                ? _purchases(state, ledger, today)
                : _payments(state, ledger, today),
          ),
        ),
        if (state.byCategory case final byCategory?
            when byCategory.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _CategoryBreakdown(
            key: const Key('tabCategoryBreakdown'),
            byCategory: byCategory,
            categories: state.categories,
            currency: tab.currency,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _purchases(TabDetailState state, TabLedger ledger, DateTime today) {
    final theme = Theme.of(context);
    final currency = ledger.tab.currency;
    if (ledger.purchases.isEmpty) {
      return Text(
        ledger.tab.isArchived
            ? 'Nothing was put on this tab.'
            : 'Nothing on this tab yet. Use Add to tab to put a purchase on it.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    void open(PurchaseLine line) =>
        context.pushUnique('/app/expenses/${line.expense.id}');

    // With a rhythm every purchase has a period: grouped, newest first.
    if (ledger.periods.isNotEmpty) {
      final periods = ledger.periods.reversed.toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < periods.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.smd),
            PeriodGroup(
              summary: periods[i],
              currency: currency,
              today: today,
              categories: state.categories,
              onOpen: open,
            ),
          ],
        ],
      );
    }
    return AppGroupedList(
      children: [
        for (final line in ledger.purchases.reversed)
          PurchaseRow(
            line: line,
            currency: currency,
            today: today,
            categoryName: state.categories[line.expense.categoryId]?.name,
            onTap: () => open(line),
          ),
      ],
    );
  }

  Widget _payments(TabDetailState state, TabLedger ledger, DateTime today) {
    final theme = Theme.of(context);
    if (ledger.payments.isEmpty) {
      return Text(
        'No payments yet.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final purchases = {for (final p in ledger.purchases) p.expense.id: p};
    return AppGroupedList(
      dividerIndent: AppSizes.iconMd + AppSpacing.smd,
      children: [
        for (final line in ledger.payments.reversed)
          PaymentHistoryTile(
            line: line,
            currency: ledger.tab.currency,
            today: today,
            purchases: purchases,
            categories: state.categories,
            onActions: () => _paymentActions(state, ledger, line),
          ),
      ],
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────

  void _edit(TabLedger ledger) =>
      context.pushUnique('${AppRouter.payLaterPath}/${ledger.tab.id}/edit');

  Future<void> _recordPayment(
    TabDetailState state,
    TabLedger ledger, {
    bool settleAll = false,
    PaymentLine? editing,
  }) async {
    final message = await PaymentSheet.show(
      context,
      ledger: ledger,
      payments: _bloc.payments,
      settleAll: settleAll,
      editing: editing,
      categories: state.categories,
      clock: _bloc.clock,
    );
    if (message != null && mounted) _show(message);
  }

  Future<void> _paymentActions(
    TabDetailState state,
    TabLedger ledger,
    PaymentLine line,
  ) async {
    if (state.busy) return;
    final currency = ledger.tab.currency;
    final action = await AppBottomSheet.show<String>(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSheetHeader(
            title:
                'Payment of '
                '${AppMoney.format(line.payment.amount, currency: currency)}',
            subtitle:
                'Paid ${TabTile.formatDay(line.payment.paidDate, today: _today)}',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              children: [
                AppListRow(
                  leading: const Icon(Icons.edit_outlined),
                  title: 'Edit payment',
                  onTap: () => Navigator.of(sheetContext).pop('edit'),
                ),
                AppListRow(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: context.tone(AppTone.critical).accent,
                  ),
                  title: 'Delete payment',
                  titleColor: context.tone(AppTone.critical).accent,
                  onTap: () => Navigator.of(sheetContext).pop('delete'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'edit':
        await _recordPayment(state, ledger, editing: line);
      case 'delete':
        await _deletePayment(ledger, line);
    }
  }

  /// Names what the delete changes: the amount owed again (this payment's
  /// money comes off its purchases; other payments' credit may cover part
  /// of it), and any credit it takes away.
  Future<void> _deletePayment(TabLedger ledger, PaymentLine line) async {
    final tab = ledger.tab;
    final money = MoneyMath.forCurrency(tab.currency);
    final owed = money.toUnits(ledger.owed);
    final credit = money.toUnits(ledger.credit);
    final net = owed - credit + money.toUnits(line.payment.amount);
    final owedAgain = math.max<int>(0, net) - owed;
    final creditLost = credit - math.max<int>(0, -net);
    String format(int units) =>
        AppMoney.format(money.toAmount(units), currency: tab.currency);

    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Delete this payment?',
      message: [
        owedAgain > 0
            ? '${format(owedAgain)} will be owed again on ${tab.name}.'
            : 'Nothing will be owed again.',
        if (creditLost > 0)
          "${tab.name}'s credit goes down by ${format(creditLost)}.",
      ].join(' '),
      confirmLabel: 'Delete',
      icon: Icons.delete_rounded,
      isDestructive: true,
    );
    if (confirmed && mounted) {
      _bloc.add(TabDetailPaymentDeleteRequested(line.payment.id));
    }
  }

  /// Archiving needs a settled tab; otherwise says why instead of trying.
  Future<void> _archive(TabLedger ledger) async {
    final tab = ledger.tab;
    final String? reason;
    if (ledger.owed > 0) {
      reason =
          '${tab.name} still owes '
          '${AppMoney.format(ledger.owed, currency: tab.currency)}. '
          'Settle it first, then archive it.';
    } else if (ledger.credit > 0) {
      reason =
          '${tab.name} holds '
          '${AppMoney.format(ledger.credit, currency: tab.currency)} in '
          'credit. Add a purchase to use it, or lower the payment that left '
          'it, then archive the tab.';
    } else {
      reason = null;
    }
    if (reason == null) {
      _bloc.add(const TabDetailArchiveRequested());
      return;
    }
    await AppDialog.show<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.inventory_2_outlined),
        title: const Text("Can't archive yet", textAlign: TextAlign.center),
        content: Text(reason!, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTab(TabLedger ledger) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Delete this tab?',
      message:
          '"${ledger.tab.name}" has no purchases or payments, so nothing '
          'else changes.',
      confirmLabel: 'Delete',
      icon: Icons.delete_rounded,
      isDestructive: true,
    );
    if (confirmed && mounted) _bloc.add(const TabDetailDeleteRequested());
  }
}

/// The tab, what it owes (or its credit), overdue, the next settle-up and
/// its totals, on one surface.
class _Header extends StatelessWidget {
  final TabLedger ledger;
  final DateTime today;

  const _Header({required this.ledger, required this.today});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tab = ledger.tab;
    final currency = tab.currency;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final AppMetric balance;
    if (ledger.owed > 0) {
      balance = AppMetric(
        label: 'Owed',
        value: AppMoney(
          amount: ledger.owed,
          currency: currency,
          role: MoneyRole.display,
        ),
      );
    } else if (ledger.credit > 0) {
      balance = AppMetric(
        label: 'In credit',
        value: AppMoney(
          amount: ledger.credit,
          currency: currency,
          role: MoneyRole.display,
        ),
      );
    } else {
      balance = AppMetric(
        label: 'Owed',
        value: Text(
          ledger.purchases.isEmpty ? 'Nothing yet' : 'Settled',
          style: theme.textTheme.headlineSmall,
        ),
      );
    }

    final settle = _settleLine();
    return AppSurface(
      key: const Key('tabHeader'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(
                icon: tabCategoryIcon(tab.category),
                color: theme.colorScheme.primary,
                size: AppSizes.avatarSm,
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tab.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (tab.contact?.trim().isNotEmpty ?? false)
                      Text(tab.contact!.trim(), style: muted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          KeyedSubtree(key: const Key('tabBalance'), child: balance),
          if (ledger.overdue > 0 || settle != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (ledger.overdue > 0)
                  StatusChip.tone(
                    label:
                        '${AppMoney.format(ledger.overdue, currency: currency)} '
                        'overdue',
                    tone: AppTone.critical,
                    icon: Icons.schedule_rounded,
                    wrapLabel: true,
                  ),
                if (settle != null) Text(settle, style: muted),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppMetric(
                  label: 'Total added',
                  value: AppMoney(
                    amount: ledger.totalAdded,
                    currency: currency,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppMetric(
                  label: 'Total paid',
                  alignEnd: true,
                  value: AppMoney(
                    amount: ledger.totalPaid,
                    currency: currency,
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

  /// The next settle-up day, worded as everywhere else
  /// ([TabTile.settleUpLine]: none while nothing is owed). Null when the
  /// notice above asks for a date instead.
  String? _settleLine() {
    if (ledger.needsSettleDate) return null;
    if (ledger.tab.rhythm is OnDemand) return 'Pay when you like';
    return TabTile.settleUpLine(ledger);
  }
}

/// This tab's purchases by expense category, largest first.
class _CategoryBreakdown extends StatelessWidget {
  final Map<String, double> byCategory;
  final Map<String, ExpenseCategory> categories;
  final String currency;

  const _CategoryBreakdown({
    super.key,
    required this.byCategory,
    required this.categories,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = MoneyMath.forCurrency(currency);
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = money.sumUnits(byCategory.values);
    return AppSection(
      title: 'By category',
      child: AppGroupedList(
        dividerIndent: AppSizes.avatarSm + AppSpacing.smd,
        children: [
          for (final MapEntry(key: id, value: amount) in entries)
            AppListRow(
              leading: IconTile(
                icon: CategoryVisuals.iconFor(categories[id]?.icon ?? ''),
                color: theme.colorScheme.primary,
                size: AppSizes.avatarSm,
              ),
              title: categories[id]?.name ?? 'Other',
              subtitle: total <= 0
                  ? null
                  : '${(money.toUnits(amount) * 100 / total).round()}%',
              trailing: AppMoney(
                amount: amount,
                currency: currency,
                textAlign: TextAlign.end,
              ),
            ),
        ],
      ),
    );
  }
}

/// The first load failed: a real error, with a way to try again.
class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: AppSpacing.pagePadding,
      children: [
        StatusCard(
          color: theme.colorScheme.error,
          icon: Icons.error_outline_rounded,
          title: "Couldn't open this tab.",
          message: message,
          trailing: TextButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}
