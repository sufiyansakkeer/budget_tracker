import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';

/// Friendly empty state shown when there are no expenses for the period.
class EmptyReportsState extends StatelessWidget {
  final VoidCallback? onAddExpense;

  const EmptyReportsState({super.key, this.onAddExpense});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.pie_chart_outline,
                size: 48,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No expenses yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                'Add expenses to see charts, trends, and insights for this period.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            if (onAddExpense != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onAddExpense,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Expense'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
