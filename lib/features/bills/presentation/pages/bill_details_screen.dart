import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/bill_entity.dart';
import '../../domain/entities/bill_enums.dart';
import '../../domain/repository/bill_repository.dart';
import '../../../expenses/domain/entities/expense_entity.dart';
import '../../../expenses/presentation/bloc/expense_bloc.dart';
import '../../../expenses/presentation/bloc/expense_event.dart';
import '../../../../core/di/injection.dart';
import '../bloc/bill_bloc.dart';
import '../bloc/bill_event.dart';
import '../bloc/bill_state.dart';
import '../../../../core/theme/app_colors_extension.dart';

/// Detailed view of a single bill.
class BillDetailsScreen extends StatefulWidget {
  final String billId;

  const BillDetailsScreen({super.key, required this.billId});

  @override
  State<BillDetailsScreen> createState() => _BillDetailsScreenState();
}

class _BillDetailsScreenState extends State<BillDetailsScreen> {
  List<BillPaymentRecord> _payments = [];

  @override
  void initState() {
    super.initState();
    context.read<BillBloc>().add(BillLoadById(widget.billId));
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    try {
      final repo = getIt<BillRepository>();
      final payments = await repo.getBillPayments(widget.billId);
      if (mounted) {
        setState(() => _payments = payments);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Details'),
        actions: [
          BlocBuilder<BillBloc, BillState>(
            builder: (context, state) {
              final bill = state.selectedBill;
              if (bill == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit bill',
                onPressed: () => context.push('/app/bills/edit/${bill.id}'),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<BillBloc, BillState>(
        listener: (context, state) {
          if (state.status == BillBlocStatus.success &&
              state.message?.contains('deleted') == true) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text('Bill deleted')));
            context.read<BillBloc>().add(const BillClearMessage());
            context.pop();
          } else if (state.status == BillBlocStatus.error) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.message ?? 'Something went wrong'),
                  backgroundColor: context.appColors.error,
                ),
              );
            context.read<BillBloc>().add(const BillClearMessage());
          }
        },
        builder: (context, state) {
          if (state.status == BillBlocStatus.loading &&
              state.selectedBill == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final bill = state.selectedBill;
          if (bill == null) {
            return const Center(child: Text('Bill not found'));
          }

          return _buildDetails(context, bill);
        },
      ),
    );
  }

  Widget _buildDetails(BuildContext context, BillEntity bill) {
    final theme = Theme.of(context);
    final status = bill.status;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: status == BillStatus.paid
                  ? LinearGradient(
                      colors: [
                        context.appColors.success,
                        context.appColors.success,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : status == BillStatus.overdue
                  ? LinearGradient(
                      colors: [
                        context.appColors.error,
                        context.appColors.error,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        context.appColors.secondaryDark,
                        context.appColors.secondary,
                      ],
                    ),
              borderRadius: AppSpacing.borderRadiusLg,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _iconForCategory(bill.category),
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  bill.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  CurrencyFormatter.format(
                    bill.amount,
                    code: bill.currency,
                    decimalDigits: 0,
                  ),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _StatusBadge(status: status),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Info card
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  _infoRow(
                    theme,
                    Icons.category_outlined,
                    'Category',
                    bill.category.label,
                  ),
                  _infoRow(
                    theme,
                    Icons.calendar_today_outlined,
                    'Due Date',
                    DateFormat('EEE, MMM d, yyyy').format(bill.dueDate),
                  ),
                  if (bill.dueTime != null)
                    _infoRow(
                      theme,
                      Icons.access_time_rounded,
                      'Due Time',
                      TimeOfDay(
                        hour: bill.dueTime!.hour,
                        minute: bill.dueTime!.minute,
                      ).format(context),
                    ),
                  if (bill.isRecurring)
                    _infoRow(
                      theme,
                      Icons.repeat_rounded,
                      'Recurrence',
                      '${bill.recurrenceType.label}'
                          '${bill.recurrenceInterval > 1 ? ' (every ${bill.recurrenceInterval})' : ''}',
                    ),
                  if (bill.reminderEnabled)
                    _infoRow(
                      theme,
                      Icons.notifications_outlined,
                      'Reminder',
                      bill.reminderOffsetDays == 0
                          ? 'On the due date'
                          : '${bill.reminderOffsetDays} day${bill.reminderOffsetDays > 1 ? 's' : ''} before',
                    ),
                  if (bill.isPaid && bill.paidDate != null)
                    _infoRow(
                      theme,
                      Icons.check_circle_outline,
                      'Paid Date',
                      DateFormat('EEE, MMM d, yyyy').format(bill.paidDate!),
                    ),
                  if (bill.note != null && bill.note!.isNotEmpty)
                    _infoRow(theme, Icons.notes_rounded, 'Note', bill.note!),
                  _infoRow(
                    theme,
                    Icons.add_circle_outline,
                    'Created',
                    DateFormat('MMM d, yyyy h:mm a').format(bill.createdAt),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Payment history (for recurring bills)
          if (_payments.isNotEmpty) ...[
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment History',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ..._payments.map(
                      (payment) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: context.appColors.success,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                DateFormat(
                                  'MMM d, yyyy',
                                ).format(payment.paidDate),
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(
                                payment.amount,
                                code: payment.currency,
                                decimalDigits: 0,
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: context.appColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Actions
          if (!bill.isPaid) ...[
            // Mark as Paid
            FilledButton.icon(
              onPressed: () => _markPaid(context, bill),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Mark as Paid'),
              style: FilledButton.styleFrom(
                backgroundColor: context.appColors.success,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Mark Paid & Add Expense
            OutlinedButton.icon(
              onPressed: () => _markPaidAndAddExpense(context, bill),
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text('Mark Paid & Add Expense'),
            ),
            const SizedBox(height: AppSpacing.md),
          ] else ...[
            // Mark as Unpaid
            OutlinedButton.icon(
              onPressed: () => _markUnpaid(context, bill),
              icon: const Icon(Icons.undo_rounded),
              label: const Text('Mark as Unpaid'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Delete
          OutlinedButton.icon(
            onPressed: () => _confirmDelete(context, bill),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.appColors.error,
              side: BorderSide(color: context.appColors.error),
            ),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete Bill'),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Future<void> _markPaid(BuildContext context, BillEntity bill) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Mark as Paid?',
      message: 'Mark "${bill.title}" as paid?',
      confirmLabel: 'Mark Paid',
      icon: Icons.check_circle_rounded,
    );
    if (confirmed && context.mounted) {
      context.read<BillBloc>().add(BillMarkPaid(bill.id));
      await _loadPayments();
    }
  }

  Future<void> _markPaidAndAddExpense(
    BuildContext context,
    BillEntity bill,
  ) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Mark Paid & Add Expense?',
      message:
          'Mark "${bill.title}" as paid and create an expense of '
          '${CurrencyFormatter.format(bill.amount, code: bill.currency)}?',
      confirmLabel: 'Confirm',
      icon: Icons.receipt_long_rounded,
    );
    if (!confirmed || !context.mounted) return;

    // Mark as paid via bill BLoC.
    context.read<BillBloc>().add(BillMarkPaid(bill.id));

    // Create the corresponding expense using the existing expense system.
    final now = DateTime.now();
    final expense = ExpenseEntity(
      id: const Uuid().v4(),
      budgetId: '', // Will be resolved by ExpenseBloc
      amount: bill.amount,
      categoryId: 'bills', // Map to the "bills" expense category
      note: 'Bill: ${bill.title}',
      date: now,
      time: now,
      createdAt: now,
      updatedAt: now,
    );

    // Access the expense BLoC to create the expense.
    // We use the ExpenseBloc from the dependency injection.
    try {
      final expenseBloc = getIt<ExpenseBloc>();
      expenseBloc.add(ExpenseCreate(expense));
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Bill paid and expense created')),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Bill paid, but failed to create expense: $e'),
              backgroundColor: context.appColors.warning,
            ),
          );
      }
    }

    await _loadPayments();
  }

  Future<void> _markUnpaid(BuildContext context, BillEntity bill) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Mark as Unpaid?',
      message: 'Mark "${bill.title}" as unpaid?',
      confirmLabel: 'Mark Unpaid',
      icon: Icons.undo_rounded,
    );
    if (confirmed && context.mounted) {
      context.read<BillBloc>().add(BillMarkUnpaid(bill.id));
    }
  }

  Future<void> _confirmDelete(BuildContext context, BillEntity bill) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Delete Bill?',
      message:
          'Are you sure you want to delete "${bill.title}"?\n\n'
          'This will also remove its scheduled reminders.',
      confirmLabel: 'Delete',
      icon: Icons.delete_rounded,
      isDestructive: true,
    );
    if (confirmed && context.mounted) {
      context.read<BillBloc>().add(BillDelete(bill.id));
    }
  }

  Widget _infoRow(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.appColors.secondary, size: 20),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForCategory(BillCategory category) {
    switch (category) {
      case BillCategory.rent:
        return Icons.home_rounded;
      case BillCategory.utilities:
        return Icons.bolt_rounded;
      case BillCategory.electricity:
        return Icons.electric_bolt_rounded;
      case BillCategory.water:
        return Icons.water_drop_rounded;
      case BillCategory.internet:
        return Icons.wifi_rounded;
      case BillCategory.phone:
        return Icons.phone_rounded;
      case BillCategory.emi:
        return Icons.payments_rounded;
      case BillCategory.insurance:
        return Icons.shield_rounded;
      case BillCategory.subscription:
        return Icons.subscriptions_rounded;
      case BillCategory.education:
        return Icons.school_rounded;
      case BillCategory.healthcare:
        return Icons.local_hospital_rounded;
      case BillCategory.government:
        return Icons.account_balance_rounded;
      case BillCategory.creditCard:
        return Icons.credit_card_rounded;
      case BillCategory.other:
        return Icons.receipt_long_rounded;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final BillStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case BillStatus.paid:
        return StatusChipStyles.healthy(context, 'Paid');
      case BillStatus.overdue:
        return StatusChipStyles.danger(context, 'Overdue');
      case BillStatus.dueToday:
        return StatusChipStyles.warning(context, 'Due Today');
      case BillStatus.upcoming:
        return StatusChipStyles.info(context, 'Upcoming');
    }
  }
}
