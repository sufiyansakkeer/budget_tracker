import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';

/// Large Save/Cancel action buttons for the expense form.
class ExpenseFormActions extends StatelessWidget {
  final bool isSaving;
  final bool isEditing;
  final VoidCallback onSave;
  final VoidCallback? onCancel;

  const ExpenseFormActions({
    super.key,
    required this.isSaving,
    required this.isEditing,
    required this.onSave,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            key: const Key('saveExpenseButton'),
            onPressed: isSaving ? null : onSave,
            icon: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
            label: Text(
              isSaving
                  ? 'Saving...'
                  : (isEditing ? 'Update Expense' : 'Add Expense'),
            ),
          ),
        ),
        if (onCancel != null) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isSaving ? null : onCancel,
              child: const Text('Cancel'),
            ),
          ),
        ],
      ],
    );
  }
}
