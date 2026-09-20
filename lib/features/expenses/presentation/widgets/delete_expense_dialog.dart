import 'package:flutter/material.dart';

import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/confirmation_dialog.dart';

/// Confirmation dialog shown before deleting an expense.
///
/// [currency] is the ISO currency code of the expense's budget.
Future<bool> showDeleteExpenseDialog(
  BuildContext context, {
  required double amount,
  required String currency,
}) {
  return ConfirmationDialog.show(
    context: context,
    title: 'Delete expense?',
    message:
        'This removes the expense of '
        '${CurrencyFormatter.format(amount, code: currency)} permanently.',
    confirmLabel: 'Delete',
    icon: Icons.delete_rounded,
    isDestructive: true,
  );
}
