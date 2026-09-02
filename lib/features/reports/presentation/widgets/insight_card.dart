import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../dashboard/domain/entities/smart_insight_entity.dart';
import '../../../../core/theme/app_colors_extension.dart';

/// Reusable insight card for the reports screen. Reuses the dashboard
/// [InsightType] and [SmartInsight] entities.
class InsightCard extends StatelessWidget {
  final String message;
  final InsightType type;

  const InsightCard({super.key, required this.message, required this.type});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = _config(context);

    return Semantics(
      label: message,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: config.color.withValues(alpha: 0.1),
          borderRadius: AppSpacing.borderRadiusLg,
          border: Border.all(color: config.color, width: 1),
        ),
        child: Row(
          children: [
            Icon(config.icon, color: config.color, size: 24),
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
      ),
    );
  }

  _Config _config(BuildContext context) {
    switch (type) {
      case InsightType.positive:
        return _Config(Icons.check_circle, context.appColors.success);
      case InsightType.warning:
        return _Config(Icons.warning, context.appColors.warning);
      case InsightType.negative:
        return _Config(Icons.error, context.appColors.error);
      case InsightType.info:
        return _Config(Icons.lightbulb, context.appColors.tertiary);
    }
  }
}

class _Config {
  final IconData icon;
  final Color color;

  _Config(this.icon, this.color);
}
