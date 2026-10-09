import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// The top of Home, without a card: a greeting with today's date, the
/// active budget's name as the screen title (tap to switch budget) and its
/// period.
///
/// The budget switcher used to be a bordered card of its own; as the title
/// it says which budget every figure below belongs to, once.
class DashboardHeader extends StatelessWidget {
  /// The active budget; null when it is not known yet.
  final String? budgetName;

  /// The budget's period, e.g. "1 Oct – 31 Oct 2026".
  final String? caption;

  /// Opens the budget switcher.
  final VoidCallback? onSwitchBudget;

  const DashboardHeader({
    super.key,
    this.budgetName,
    this.caption,
    this.onSwitchBudget,
  });

  /// The clock for the greeting and date. Golden tests fix it; the app
  /// always uses the device time.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  static String greetingFor(DateTime now) {
    final hour = now.hour;
    if (hour < 5) return 'Good night';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final now = clock();
    final name = budgetName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${greetingFor(now)} · ${DateFormat('EEE d MMM').format(now)}',
          style: context.appTypography.eyebrow.copyWith(color: muted),
        ),
        const SizedBox(height: AppSpacing.xxs),
        if (name != null)
          Semantics(
            button: onSwitchBudget != null,
            header: true,
            label: 'Active budget: $name. Switch budget',
            onTap: onSwitchBudget,
            excludeSemantics: true,
            child: InkWell(
              onTap: onSwitchBudget,
              borderRadius: AppSpacing.borderRadiusSm,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.touchTarget,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: theme.textTheme.headlineSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onSwitchBudget != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Icon(Icons.expand_more_rounded, color: muted),
                    ],
                  ],
                ),
              ),
            ),
          ),
        if (caption != null)
          Text(
            caption!,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
      ],
    );
  }
}
