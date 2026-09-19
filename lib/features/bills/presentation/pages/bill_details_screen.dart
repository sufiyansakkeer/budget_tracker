import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../expenses/domain/entities/expense_entity.dart';
import '../../../expenses/presentation/bloc/expense_bloc.dart';
import '../../../expenses/presentation/bloc/expense_event.dart';
import '../../domain/entities/bill_entity.dart';
import '../../domain/entities/bill_enums.dart';
import '../../domain/repository/bill_repository.dart';
import '../bloc/bill_bloc.dart';
import '../bloc/bill_event.dart';
import '../bloc/bill_state.dart';
import 'bill_widgets.dart';

/// Detailed view of a single bill.
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

  @override
  void initState() {
    super.initState();
    context.read<BillBloc>().add(BillLoadById(widget.billId));
    _loadPayments();
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

  Future<void> _markPaid(BillEntity bill) async {
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

  Future<void> _markPaidAndAddExpense(BillEntity bill) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Mark paid & add expense?',
      message:
          '"${bill.title}" will be marked paid and an expense of '
          '${CurrencyFormatter.format(bill.amount, code: bill.currency)} '
          'will be recorded in your active budget.',
      confirmLabel: 'Confirm',
      icon: Icons.receipt_long_rounded,
    );
    if (!confirmed || !mounted) return;

    context.read<BillBloc>().add(BillMarkPaid(bill.id));

    // Create the corresponding expense through the existing expense system.
    final now = DateTime.now();
    final expense = ExpenseEntity(
      id: const Uuid().v4(),
      budgetId: '', // Resolved to the active budget by ExpenseBloc.
      amount: bill.amount,
      categoryId: 'bills',
      note: 'Bill: ${bill.title}',
      date: now,
      time: now,
      createdAt: now,
      updatedAt: now,
    );
    try {
      getIt<ExpenseBloc>().add(ExpenseCreate(expense));
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Marked paid. Expense added to your active budget.',
              ),
            ),
          );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                "Marked paid, but the expense couldn't be added. Add it from "
                'Expenses.',
              ),
            ),
          );
      }
    }
  }

  Future<void> _markUnpaid(BillEntity bill) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Mark as unpaid?',
      message: '"${bill.title}" will go back to unpaid.',
      confirmLabel: 'Mark unpaid',
      icon: Icons.undo_rounded,
    );
    if (confirmed && mounted) {
      context.read<BillBloc>().add(BillMarkUnpaid(bill.id));
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
                    : () => context.push('/app/bills/edit/${bill.id}'),
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
            child = _Details(
              key: const ValueKey('details'),
              bill: state.selectedBill!,
              payments: _payments,
              paymentsFailed: _paymentsFailed,
              busy: state.isBusy,
              onMarkPaid: () => _markPaid(state.selectedBill!),
              onMarkPaidAndExpense: () =>
                  _markPaidAndAddExpense(state.selectedBill!),
              onMarkUnpaid: () => _markUnpaid(state.selectedBill!),
              onDelete: () => _confirmDelete(state.selectedBill!),
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
  final List<BillPaymentRecord> payments;
  final bool paymentsFailed;
  final bool busy;
  final VoidCallback onMarkPaid;
  final VoidCallback onMarkPaidAndExpense;
  final VoidCallback onMarkUnpaid;
  final VoidCallback onDelete;

  const _Details({
    super.key,
    required this.bill,
    required this.payments,
    required this.paymentsFailed,
    required this.busy,
    required this.onMarkPaid,
    required this.onMarkPaidAndExpense,
    required this.onMarkUnpaid,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final status = bill.status;
    final color = BillVisuals.colorFor(context, status);

    return ListView(
      padding: AppSpacing.pagePadding,
      children: [
        // Hero
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.mlg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconTile(
                    icon: BillVisuals.iconFor(bill.category),
                    color: color,
                    size: AppSizes.avatarLg,
                  ),
                  const SizedBox(width: AppSpacing.md),
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
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          bill.category.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyFormatter.format(
                          bill.amount,
                          code: bill.currency,
                        ),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  BillVisuals.chip(context, status),
                ],
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
                  Text(
                    BillVisuals.dueText(bill),
                    style: theme.textTheme.bodyMedium?.copyWith(color: color),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Facts
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            children: [
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
                  valueColor: colors.success,
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

        // Payment history
        if (payments.isNotEmpty || paymentsFailed) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payment history', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                if (paymentsFailed)
                  Text(
                    "Couldn't load payment history.",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  for (final payment in payments)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: AppSizes.iconSm,
                            color: colors.success,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              DateFormat('d MMM yyyy').format(payment.paidDate),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(
                              payment.amount,
                              code: payment.currency,
                              decimalDigits: 0,
                            ),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.lg),

        // Actions
        if (!bill.isPaid) ...[
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
        ] else
          OutlinedButton.icon(
            onPressed: busy ? null : onMarkUnpaid,
            icon: const Icon(Icons.undo_rounded),
            label: const Text('Mark as unpaid'),
          ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: busy ? null : onDelete,
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.error,
            side: BorderSide(color: colors.error.withValues(alpha: 0.6)),
          ),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Delete bill'),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Added ${DateFormat('d MMM yyyy').format(bill.createdAt)}',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
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

  const _FactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
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
        ],
      ),
    );
  }
}
