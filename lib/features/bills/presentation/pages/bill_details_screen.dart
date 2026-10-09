import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/events/refresh_bus.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_list.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_section.dart';
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../budget/domain/usecases/manage_budget_usecase.dart';
import '../../domain/entities/bill_entity.dart';
import '../../domain/entities/bill_enums.dart';
import '../../domain/repository/bill_repository.dart';
import '../bloc/bill_bloc.dart';
import '../bloc/bill_event.dart';
import '../bloc/bill_state.dart';
import 'bill_budget_link.dart';
import 'bill_payment_dialogs.dart';
import 'bill_widgets.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/navigation/push_unique.dart';
import '../../../../core/widgets/app_animated_size.dart';

/// One bill: what it is and the amount on one surface with its facts
/// (paid from, due, repeats, reminder), then the pay actions together right
/// under it, the payment history and delete.
class BillDetailsScreen extends StatefulWidget {
  final String billId;

  const BillDetailsScreen({super.key, required this.billId});

  @override
  State<BillDetailsScreen> createState() => _BillDetailsScreenState();
}

class _BillDetailsScreenState extends State<BillDetailsScreen> {
  List<BillPaymentRecord> _payments = const [];
  bool _paymentsFailed = false;
  bool _deleting = false;
  Map<String, BudgetEntity> _budgetsById = const {};
  bool _budgetsLoaded = false;
  StreamSubscription<void>? _budgetSubscription;

  @override
  void initState() {
    super.initState();
    context.read<BillBloc>().add(BillLoadById(widget.billId));
    _loadPayments();
    _loadBudgets();
    _budgetSubscription = RefreshBuses.budgets.changes.listen((_) {
      if (mounted) _loadBudgets();
    });
  }

  @override
  void dispose() {
    _budgetSubscription?.cancel();
    super.dispose();
  }

  /// Names the budget the bill is paid from.
  Future<void> _loadBudgets() async {
    try {
      final budgets = await getIt<ManageBudgetUseCase>().getAll();
      if (!mounted) return;
      setState(() {
        _budgetsById = {for (final b in budgets) b.id: b};
        _budgetsLoaded = true;
      });
    } catch (_) {
      // The "Paid from" line falls back to a neutral label.
    }
  }

  /// "Paid from" value: the budget label, "Not linked", or a fallback when
  /// the budget can't be named.
  String _paidFromLabel(BillEntity bill) {
    final id = bill.budgetId;
    if (id == null) return BillBudgetLink.notLinked;
    final budget = _budgetsById[id];
    if (budget != null) {
      return BillBudgetLink.budgetLabel(budget, DateTime.now());
    }
    return _budgetsLoaded ? 'A budget that no longer exists' : 'A budget';
  }

  Future<void> _loadPayments() async {
    try {
      final payments = await getIt<BillRepository>().getBillPayments(
        widget.billId,
      );
      if (!mounted) return;
      setState(() {
        _payments = payments;
        _paymentsFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _paymentsFailed = true);
    }
  }

  Future<void> _confirmDelete(BillEntity bill) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Delete this bill?',
      message:
          '"${bill.title}" and its scheduled reminders will be removed. '
          'Expenses you already recorded are kept.',
      confirmLabel: 'Delete',
      icon: Icons.delete_rounded,
      isDestructive: true,
    );
    if (confirmed && mounted) {
      setState(() => _deleting = true);
      context.read<BillBloc>().add(BillDelete(bill.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill'),
        actions: [
          BlocBuilder<BillBloc, BillState>(
            builder: (context, state) {
              final bill = state.selectedBill;
              if (bill == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit bill',
                onPressed: state.isBusy
                    ? null
                    : () => context.pushUnique('/app/bills/edit/${bill.id}'),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<BillBloc, BillState>(
        listener: (context, state) {
          if (state.status == BillBlocStatus.success) {
            final wasDelete = _deleting;
            context.read<BillBloc>().add(const BillClearMessage());
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    state.message ?? (wasDelete ? 'Bill deleted' : 'Updated'),
                  ),
                ),
              );
            if (wasDelete) {
              if (context.canPop()) context.pop();
            } else {
              _loadPayments();
            }
          } else if (state.status == BillBlocStatus.error) {
            setState(() => _deleting = false);
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.message ?? 'Something went wrong'),
                ),
              );
            context.read<BillBloc>().add(const BillClearMessage());
          }
        },
        builder: (context, state) {
          final Widget child;
          if (state.status == BillBlocStatus.loading &&
              state.selectedBill == null) {
            child = const FormSkeleton(key: ValueKey('loading'), rows: 4);
          } else if (state.selectedBill == null) {
            child = EmptyState(
              key: const ValueKey('missing'),
              icon: Icons.receipt_long_outlined,
              title: 'Bill not found',
              message: 'It may have been deleted.',
              actionLabel: 'Back to bills',
              actionIcon: Icons.arrow_back_rounded,
              onAction: () =>
                  context.canPop() ? context.pop() : context.go('/app/bills'),
            );
          } else {
            final bill = state.selectedBill!;
            final linkedBudget = bill.budgetId == null
                ? null
                : _budgetsById[bill.budgetId];
            child = _Details(
              key: const ValueKey('details'),
              bill: bill,
              paidFrom: _paidFromLabel(bill),
              payments: _payments,
              paymentsFailed: _paymentsFailed,
              busy: state.isBusy,
              onMarkPaid: () => bill.budgetId == null
                  ? BillPaymentDialogs.markPaid(context, bill)
                  : BillPaymentDialogs.paidOutsideBudget(
                      context,
                      bill,
                      budget: linkedBudget,
                      today: DateTime.now(),
                    ),
              onMarkPaidAndExpense: () =>
                  BillPaymentDialogs.payWithExpense(context, bill),
              onMarkUnpaid: () => BillPaymentDialogs.markUnpaid(context, bill),
              onChangeBudget: () =>
                  context.pushUnique('/app/bills/edit/${bill.id}'),
              onDelete: () => _confirmDelete(bill),
            );
          }
          return AppStateSwitcher(child: child);
        },
      ),
    );
  }
}

class _Details extends StatelessWidget {
  final BillEntity bill;
  final String paidFrom;
  final List<BillPaymentRecord> payments;
  final bool paymentsFailed;
  final bool busy;

  /// Plain mark-paid: "Mark as paid" for an unlinked bill, "Paid outside
  /// this budget" for a linked one.
  final VoidCallback onMarkPaid;
  final VoidCallback onMarkPaidAndExpense;
  final VoidCallback onMarkUnpaid;
  final VoidCallback onChangeBudget;
  final VoidCallback onDelete;

  const _Details({
    super.key,
    required this.bill,
    required this.paidFrom,
    required this.payments,
    required this.paymentsFailed,
    required this.busy,
    required this.onMarkPaid,
    required this.onMarkPaidAndExpense,
    required this.onMarkUnpaid,
    required this.onChangeBudget,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = bill.status;
    final color = BillVisuals.colorFor(context, status);
    final linked = bill.budgetId != null;

    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return ListView(
      padding: AppSpacing.pagePadding,
      children: [
        // The bill and its facts on one surface.
        AppSurface(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.mlg,
            AppSpacing.mlg,
            AppSpacing.mlg,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconTile(
                    icon: BillVisuals.iconFor(bill.category),
                    color: color,
                    animate: true,
                  ),
                  const SizedBox(width: AppSpacing.smd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bill.title,
                          style: theme.textTheme.titleLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(bill.category.label, style: muted),
                        // Under the title rather than beside it, so a long
                        // title keeps its width at large text sizes.
                        const SizedBox(height: AppSpacing.xs),
                        BillVisuals.chip(context, status),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppMoney(
                amount: bill.amount,
                currency: bill.currency,
                role: MoneyRole.display,
              ),
              const SizedBox(height: AppSpacing.xs),
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
                      BillVisuals.dueText(bill),
                      style: theme.textTheme.bodyMedium?.copyWith(color: color),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Divider(color: theme.colorScheme.outlineVariant),
              _FactRow(
                key: const ValueKey('paidFrom'),
                icon: linked
                    ? Icons.account_balance_wallet_outlined
                    : Icons.link_off_rounded,
                label: 'Paid from',
                value: paidFrom,
                trailing: TextButton(
                  onPressed: busy ? null : onChangeBudget,
                  child: const Text('Change'),
                ),
              ),
              _FactRow(
                icon: Icons.calendar_today_outlined,
                label: 'Due date',
                value: DateFormat('EEE, d MMM yyyy').format(bill.dueDate),
              ),
              _FactRow(
                icon: Icons.access_time_rounded,
                label: 'Due time',
                value: bill.dueTime == null
                    ? '9:00 AM (default)'
                    : TimeOfDay(
                        hour: bill.dueTime!.hour,
                        minute: bill.dueTime!.minute,
                      ).format(context),
              ),
              _FactRow(
                icon: Icons.repeat_rounded,
                label: 'Repeats',
                value: !bill.isRecurring
                    ? 'One-time bill'
                    : bill.recurrenceInterval > 1
                    ? 'Every ${bill.recurrenceInterval} '
                          '${bill.recurrenceType.label.toLowerCase().replaceAll('ly', 's')}'
                    : bill.recurrenceType.label,
              ),
              _FactRow(
                icon: Icons.notifications_outlined,
                label: 'Reminder',
                value: !bill.reminderEnabled
                    ? 'Off'
                    : bill.reminderOffsetDays == 0
                    ? 'On the due date'
                    : '${bill.reminderOffsetDays} '
                          '${bill.reminderOffsetDays == 1 ? 'day' : 'days'} before',
              ),
              if (bill.isPaid && bill.paidDate != null)
                _FactRow(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Paid on',
                  value: DateFormat('EEE, d MMM yyyy').format(bill.paidDate!),
                  valueColor: context.tone(AppTone.positive).accent,
                ),
              if (bill.note != null && bill.note!.trim().isNotEmpty)
                _FactRow(
                  icon: Icons.notes_rounded,
                  label: 'Note',
                  value: bill.note!.trim(),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Paying, all in one place right under the bill. The paid and
        // unpaid sets cross-fade and the block resizes smoothly, so marking
        // a bill paid feels like one change.
        AppAnimatedSize(
          duration: AppMotion.respectReducedMotion(context, AppMotion.medium),
          curve: AppMotion.standardCurve,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: AppMotion.respectReducedMotion(
              context,
              AppMotion.standard,
            ),
            switchInCurve: AppMotion.enter,
            switchOutCurve: AppMotion.exit,
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.passthrough,
              alignment: Alignment.topCenter,
              children: [...previous, ?current],
            ),
            child: bill.isPaid
                ? OutlinedButton.icon(
                    key: const ValueKey('paidActions'),
                    onPressed: busy ? null : onMarkUnpaid,
                    icon: const Icon(Icons.undo_rounded),
                    label: const Text('Mark as unpaid'),
                  )
                // A linked bill is paid from its budget by default: plain
                // "paid" would release the money set aside without
                // spending it, so it becomes the secondary action.
                : linked
                ? Column(
                    key: const ValueKey('linkedUnpaidActions'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: busy ? null : onMarkPaidAndExpense,
                        icon: const Icon(Icons.receipt_long_rounded),
                        label: const Text('Mark paid & record expense'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: busy ? null : onMarkPaid,
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Paid outside this budget'),
                      ),
                    ],
                  )
                : Column(
                    key: const ValueKey('unpaidActions'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: busy ? null : onMarkPaid,
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Mark as paid'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton.tonalIcon(
                        onPressed: busy ? null : onMarkPaidAndExpense,
                        icon: const Icon(Icons.receipt_long_rounded),
                        label: const Text('Mark paid & add expense'),
                      ),
                    ],
                  ),
          ),
        ),

        // Payment history
        if (payments.isNotEmpty || paymentsFailed) ...[
          const SizedBox(height: AppSpacing.xl),
          AppSection(
            title: 'Payment history',
            child: paymentsFailed
                ? Text("Couldn't load payment history.", style: muted)
                : AppGroupedList(
                    children: [
                      for (final payment in payments)
                        AppListRow(
                          leading: Icon(
                            Icons.check_circle_rounded,
                            size: AppSizes.iconMd,
                            color: context.tone(AppTone.positive).accent,
                          ),
                          title: DateFormat(
                            'd MMM yyyy',
                          ).format(payment.paidDate),
                          trailing: AppMoney(
                            amount: payment.amount,
                            currency: payment.currency,
                            textAlign: TextAlign.end,
                          ),
                        ),
                    ],
                  ),
          ),
        ],

        const SizedBox(height: AppSpacing.lg),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: busy ? null : onDelete,
            style: TextButton.styleFrom(
              foregroundColor: context.tone(AppTone.critical).accent,
            ),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete bill'),
          ),
        ),
        Text(
          'Added ${DateFormat('d MMM yyyy').format(bill.createdAt)}',
          style: muted,
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;

  const _FactRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: AppSizes.iconMd,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(color: valueColor),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}
