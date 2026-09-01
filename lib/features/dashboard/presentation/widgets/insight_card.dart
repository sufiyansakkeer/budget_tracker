import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../domain/entities/smart_insight_entity.dart';

class InsightCard extends StatelessWidget {
  final String message;
  final InsightType type;

  const InsightCard({super.key, required this.message, required this.type});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = _getInsightConfig(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: config.backgroundColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: config.backgroundColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(config.icon, color: config.backgroundColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _InsightConfig _getInsightConfig(BuildContext context) {
    final appColors = context.appColors;
    switch (type) {
      case InsightType.positive:
        return _InsightConfig(
          icon: Icons.check_circle,
          backgroundColor: appColors.success,
        );
      case InsightType.warning:
        return _InsightConfig(
          icon: Icons.warning,
          backgroundColor: appColors.warning,
        );
      case InsightType.negative:
        return _InsightConfig(
          icon: Icons.error,
          backgroundColor: appColors.error,
        );
      case InsightType.info:
        return _InsightConfig(
          icon: Icons.info,
          backgroundColor: appColors.primary,
        );
    }
  }
}

class _InsightConfig {
  final IconData icon;
  final Color backgroundColor;

  _InsightConfig({required this.icon, required this.backgroundColor});
}
