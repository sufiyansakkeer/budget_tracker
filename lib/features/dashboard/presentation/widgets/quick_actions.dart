import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/navigation/push_unique.dart';

/// Secondary destinations reachable from the dashboard. Adding an expense is
/// the FAB, so it is intentionally not repeated here.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _Action(
        icon: Icons.receipt_long_rounded,
        label: 'Add bill',
        onTap: () => context.pushUnique('/app/bills/add'),
      ),
      _Action(
        icon: Icons.event_repeat_rounded,
        label: 'Bills',
        onTap: () => context.pushUnique('/app/bills'),
      ),
      _Action(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Budgets',
        onTap: () => context.pushUnique('/app/budgets'),
      ),
      _Action(
        icon: Icons.insights_rounded,
        label: 'Reports',
        onTap: () => context.go('/app/reports'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 480 ? 4 : 2;
        final spacing = AppSpacing.sm;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final a in actions)
              SizedBox(
                width: width,
                child: _QuickActionCard(action: a),
              ),
          ],
        );
      },
    );
  }
}

class _Action {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, required this.onTap});
}

class _QuickActionCard extends StatelessWidget {
  final _Action action;
  const _QuickActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: action.onTap,
      color: theme.colorScheme.surfaceContainer,
      showBorder: false,
      borderRadius: AppSpacing.borderRadiusMd,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smd,
        vertical: AppSpacing.smd,
      ),
      child: Row(
        children: [
          IconTile(
            icon: action.icon,
            color: theme.colorScheme.primary,
            size: AppSizes.avatarSm,
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Text(
              action.label,
              style: theme.textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
