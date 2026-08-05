import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Confirmation dialog shown before deleting an expense.
Future<bool> showDeleteExpenseDialog(
  BuildContext context, {
  required double amount,
  required String currency,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete expense?'),
      content: Text(
        'This will permanently remove the expense of $currency$amount. '
        'This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('confirmDeleteExpense'),
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.dangerRed),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}
