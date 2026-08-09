import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

/// A small pill-shaped status indicator combining an icon + label.
///
/// Used instead of relying on color alone so status is accessible via text
/// and icon too.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool filled;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: filled ? Colors.white : color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: filled ? Colors.white : color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Factory helpers for common statuses.
class StatusChipStyles {
  StatusChipStyles._();

  static StatusChip healthy(String label) => StatusChip(
    label: label,
    color: AppColors.success,
    icon: Icons.check_circle_rounded,
  );

  static StatusChip warning(String label) => StatusChip(
    label: label,
    color: AppColors.warning,
    icon: Icons.warning_amber_rounded,
  );

  static StatusChip danger(String label) => StatusChip(
    label: label,
    color: AppColors.error,
    icon: Icons.error_rounded,
  );

  static StatusChip info(String label) => StatusChip(
    label: label,
    color: AppColors.primary,
    icon: Icons.info_rounded,
  );
}
