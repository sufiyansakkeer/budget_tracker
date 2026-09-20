import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/smart_insight_entity.dart';

/// A single Smart Insight message, styled by severity with icon + tint so the
/// meaning is clear without relying on color alone.
class InsightCard extends StatelessWidget {
  final String message;
  final InsightType type;
  final VoidCallback? onTap;

  const InsightCard({
    super.key,
    required this.message,
    required this.type,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final (icon, color, title) = switch (type) {
      InsightType.positive => (
        Icons.thumb_up_alt_rounded,
        colors.success,
        'Looking good',
      ),
      InsightType.warning => (
        Icons.warning_amber_rounded,
        colors.warning,
        'Heads up',
      ),
      InsightType.negative => (
        Icons.error_rounded,
        colors.error,
        'Needs attention',
      ),
      InsightType.info => (
        Icons.lightbulb_rounded,
        colors.info,
        'Did you know',
      ),
    };

    return Semantics(
      label: '$title. $message',
      child: ExcludeSemantics(
        child: StatusCard(
          color: color,
          icon: icon,
          title: title,
          message: message,
          onTap: onTap,
        ),
      ),
    );
  }
}
