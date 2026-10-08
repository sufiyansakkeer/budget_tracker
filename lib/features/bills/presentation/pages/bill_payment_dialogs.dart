import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../dashboard/domain/services/bill_occurrence_enumerator.dart';
import '../../../expenses/domain/entities/expense_entity.dart';
import '../../domain/entities/bill_entity.dart';
import '../../domain/entities/bill_enums.dart';
import '../../domain/entities/bill_failure.dart';
import '../../domain/usecases/mark_bill_unpaid_usecase.dart';
import '../../domain/usecases/pay_bill_usecase.dart';
import '../bloc/bill_bloc.dart';
import '../bloc/bill_event.dart';

/// Confirmations for paying and un-paying a bill, shared by the bills list
/// and bill details so both say exactly what will happen to the budget.
///
/// Each one reads the [BillBloc] from [context] and dispatches the event
/// only when the user confirms.
class BillPaymentDialogs {
  BillPaymentDialogs._();

  /// "Mark paid & record expense": names the budget the expense will go to
  /// and records payment, bill update and expense in one step. When no
  /// budget can take the payment (none running in the bill's currency), it
  /// says so instead of asking.
  static Future<void> payWithExpense(
    BuildContext context,
    BillEntity bill,
  ) async {
    final bloc = context.read<BillBloc>();
    final messenger = ScaffoldMessenger.of(context);

    String? budgetName;
    try {
      final target = await getIt<PayBillUseCase>().targetBudgetFor(bill.id);
      switch (target) {
        case BillSuccess(:final data):
          budgetName = data.name;
        case BillError(:final failure):
          if (failure.type == BillErrorType.invalidInput) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(failure.message)));
            return;
          }
      }
    } catch (_) {
      // Fall back to the generic wording; the payment itself still checks.
    }
    if (!context.mounted) return;

    final amount = CurrencyFormatter.format(bill.amount, code: bill.currency);
    final where =
        budgetName ?? 'the budget it is paid from, or your active budget';
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Mark paid & record expense?',
      message:
          '"${bill.title}" will be marked paid and an expense of $amount '
          'will be recorded in $where.${_nextOccurrence(bill)}',
      confirmLabel: 'Confirm',
      icon: Icons.receipt_long_rounded,
    );
    if (confirmed) bloc.add(BillPayWithExpense(bill.id));
  }

  /// Plain "Mark as paid" for a bill that isn't linked to a budget: no
  /// expense, no budget affected.
  static Future<void> markPaid(BuildContext context, BillEntity bill) async {
    final bloc = context.read<BillBloc>();
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
    if (confirmed) bloc.add(BillMarkPaid(bill.id));
  }

  /// "Paid outside this budget" for a linked bill: marks it paid without an
  /// expense. When [budget] (the linked budget, if known) is setting this
  /// occurrence aside on [today], it says that money is released into its
  /// safe-to-spend. Otherwise (archived, ended, another currency, due after
  /// its end, or unknown) nothing is set aside, so it asks with the plain
  /// [markPaid] wording instead of promising a change that won't happen.
  static Future<void> paidOutsideBudget(
    BuildContext context,
    BillEntity bill, {
    BudgetEntity? budget,
    required DateTime today,
  }) async {
    if (!BillOccurrenceEnumerator.setsAsideCurrentOccurrence(
      bill,
      budget,
      today,
    )) {
      return markPaid(context, bill);
    }
    final bloc = context.read<BillBloc>();
    final amount = CurrencyFormatter.format(bill.amount, code: bill.currency);
    final whose = "${budget!.name}'s";
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Paid outside this budget?',
      message:
          '"${bill.title}" won\'t be recorded as an expense, so $amount will '
          'stop being set aside and $whose safe-to-spend will go up by that '
          'amount. Use this only if you paid it from money outside this '
          'budget.${_nextOccurrence(bill)}',
      confirmLabel: 'Mark paid',
      icon: Icons.check_circle_outline_rounded,
    );
    if (confirmed) bloc.add(BillMarkPaid(bill.id));
  }

  /// "Mark as unpaid": names the expense that recorded the payment, which
  /// is deleted with it so the bill is set aside again without also
  /// counting as spent.
  static Future<void> markUnpaid(BuildContext context, BillEntity bill) async {
    final bloc = context.read<BillBloc>();

    // Null when the lookup failed: the use case still deletes whatever it
    // finds, so the dialog must not claim expenses are kept.
    List<ExpenseEntity>? expenses;
    try {
      final result = await getIt<MarkBillUnpaidUseCase>().expensesToRemove(
        bill.id,
      );
      if (result case BillSuccess(:final data)) expenses = data;
    } catch (_) {
      // Unknown: worded as such below.
    }
    if (!context.mounted) return;

    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Mark as unpaid?',
      message: unpaidMessage(bill, expenses),
      confirmLabel: 'Mark unpaid',
      icon: Icons.undo_rounded,
      isDestructive: expenses == null || expenses.isNotEmpty,
    );
    if (confirmed) bloc.add(BillMarkUnpaid(bill.id));
  }

  /// Copy for [markUnpaid], given the expenses that will be deleted, or
  /// null when they could not be looked up.
  static String unpaidMessage(BillEntity bill, List<ExpenseEntity>? expenses) {
    final title = '"${bill.title}" will go back to unpaid';
    if (expenses == null) {
      return '$title. Any expense recorded when it was marked paid will be '
          'deleted.';
    }
    if (expenses.isEmpty) {
      return '$title. Expenses already recorded for it are kept.';
    }
    if (expenses.length == 1) {
      final e = expenses.single;
      final note = e.note?.trim().isNotEmpty == true
          ? e.note!.trim()
          : 'Bill: ${bill.title}';
      final amount = CurrencyFormatter.format(e.amount, code: bill.currency);
      final date = DateFormat('d MMM yyyy').format(e.date);
      return '$title and the expense "$note" ($amount, $date) recorded for '
          'it will be deleted.';
    }
    final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final amount = CurrencyFormatter.format(total, code: bill.currency);
    return '$title and the ${expenses.length} expenses recorded for it '
        '($amount) will be deleted.';
  }

  static String _nextOccurrence(BillEntity bill) =>
      bill.isRecurring && bill.recurrenceType != RecurrenceType.none
      ? ' Its due date moves to the next '
            '${bill.recurrenceType.label.toLowerCase()} occurrence.'
      : '';
}
