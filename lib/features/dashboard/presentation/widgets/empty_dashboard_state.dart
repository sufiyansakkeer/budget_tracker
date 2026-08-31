import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';

enum EmptyStateType { noBudget, noExpenses }

class EmptyDashboardState extends StatelessWidget {
  final EmptyStateType type;
  final VoidCallback? onAction;

  const EmptyDashboardState({super.key, required this.type, this.onAction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final config = _getEmptyStateConfig();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(config.icon, size: 56, color: colorScheme.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              config.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              config.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(config.actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _EmptyStateConfig _getEmptyStateConfig() {
    switch (type) {
      case EmptyStateType.noBudget:
        return _EmptyStateConfig(
          icon: Icons.account_balance_wallet_outlined,
          title: 'No Budget Set',
          message: 'Create a budget to start tracking your expenses',
          actionLabel: 'Create Budget',
        );
      case EmptyStateType.noExpenses:
        return _EmptyStateConfig(
          icon: Icons.receipt_long_outlined,
          title: 'No Expenses Yet',
          message: 'Add your first expense to begin tracking',
          actionLabel: 'Add First Expense',
        );
    }
  }
}

class _EmptyStateConfig {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;

  _EmptyStateConfig({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
  });
}
