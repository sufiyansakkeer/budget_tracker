import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/currency/currency_formatter.dart';
import '../../../../../core/domain/entities/budget_entity.dart';
import '../../../domain/entities/expense_entity.dart';

/// Lightweight bottom sheet that shows budget & expense details when the user
/// taps the info icon on an expense tile in combined mode.
class BudgetInfoBottomSheet extends StatelessWidget {
  final ExpenseEntity expense;
  final BudgetEntity? budget;
  final String? categoryName;

  const BudgetInfoBottomSheet({
    super.key,
    required this.expense,
    this.budget,
    this.categoryName,
  });

  /// Shows the bottom sheet. Safe for SafeArea — uses no wrapper.
  static void show({
    required BuildContext context,
    required ExpenseEntity expense,
    required BudgetEntity? budget,
    String? categoryName,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (_) => BudgetInfoBottomSheet(
        expense: expense,
        budget: budget,
        categoryName: categoryName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat('d MMM yyyy');
    final timeFmt = DateFormat('h:mm a');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Text(
            'Expense Information',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Budget
          _infoRow(
            context,
            label: 'Budget',
            value: budget?.name ?? 'Unknown',
            icon: Icons.account_balance_wallet_rounded,
          ),
          const SizedBox(height: AppSpacing.md),

          // Category
          if (categoryName != null) ...[
            _infoRow(
              context,
              label: 'Category',
              value: categoryName!,
              icon: Icons.category_rounded,
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Amount
          _infoRow(
            context,
            label: 'Amount',
            value: CurrencyFormatter.format(expense.amount),
            icon: Icons.payments_rounded,
          ),
          const SizedBox(height: AppSpacing.md),

          // Date
          _infoRow(
            context,
            label: 'Date',
            value: dateFmt.format(expense.date),
            icon: Icons.calendar_today_rounded,
          ),
          const SizedBox(height: AppSpacing.md),

          // Time
          _infoRow(
            context,
            label: 'Time',
            value: timeFmt.format(expense.time),
            icon: Icons.access_time_rounded,
          ),

          const SizedBox(height: AppSpacing.lg),

          // Close button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
