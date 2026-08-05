import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/entities/smart_insight_entity.dart';

class InsightCard extends StatelessWidget {
  final String message;
  final InsightType type;

  const InsightCard({super.key, required this.message, required this.type});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = _getInsightConfig();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: config.backgroundColor.withValues(alpha: 0.1),
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(color: config.backgroundColor, width: 1),
      ),
      child: Row(
        children: [
          Icon(config.icon, color: config.backgroundColor, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _InsightConfig _getInsightConfig() {
    switch (type) {
      case InsightType.positive:
        return _InsightConfig(
          icon: Icons.check_circle,
          backgroundColor: AppColors.safeGreen,
        );
      case InsightType.warning:
        return _InsightConfig(
          icon: Icons.warning,
          backgroundColor: AppColors.warningOrange,
        );
      case InsightType.negative:
        return _InsightConfig(
          icon: Icons.error,
          backgroundColor: AppColors.dangerRed,
        );
      case InsightType.info:
        return _InsightConfig(
          icon: Icons.info,
          backgroundColor: AppColors.primary,
        );
    }
  }
}

class _InsightConfig {
  final IconData icon;
  final Color backgroundColor;

  _InsightConfig({required this.icon, required this.backgroundColor});
}
