import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/currency/currency_formatter.dart';
import '../../../../../core/domain/entities/budget_entity.dart';
import '../../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../../core/widgets/app_card.dart';
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

  /// Shows the bottom sheet.
  static void show({
    required BuildContext context,
    required ExpenseEntity expense,
    required BudgetEntity? budget,
    String? categoryName,
  }) {
    AppBottomSheet.show<void>(
      context: context,
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
    final dateFmt = DateFormat('EEE, d MMM yyyy');
    final timeFmt = DateFormat('h:mm a');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSheetHeader(
          title: 'Expense Information',
          subtitle: 'This expense belongs to one budget only.',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Budget',
                value: budget?.name ?? 'Unknown budget',
                color: theme.colorScheme.primary,
              ),
              if (categoryName != null)
                _InfoRow(
                  icon: Icons.category_rounded,
                  label: 'Category',
                  value: categoryName!,
                ),
              _InfoRow(
                icon: Icons.payments_rounded,
                label: 'Amount',
                value: CurrencyFormatter.format(
                  expense.amount,
                  code: budget?.currency,
                ),
              ),
              _InfoRow(
                icon: Icons.calendar_today_rounded,
                label: 'Date',
                value: dateFmt.format(expense.date),
              ),
              _InfoRow(
                icon: Icons.access_time_rounded,
                label: 'Time',
                value: timeFmt.format(expense.time),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          IconTile(
            icon: icon,
            color: color ?? theme.colorScheme.onSurfaceVariant,
            size: AppSizes.avatarSm,
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
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
