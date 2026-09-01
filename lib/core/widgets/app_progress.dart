import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../theme/app_colors_extension.dart';

/// A reusable progress bar with semantic color derived from utilization.
class AppProgress extends StatelessWidget {
  /// 0.0 – 1.0 (or beyond 1.0 to indicate over-budget).
  final double value;
  final double height;
  final bool showLabel;

  const AppProgress({
    super.key,
    required this.value,
    this.height = 8,
    this.showLabel = false,
  });

  /// Returns the semantic color for a utilization value using the given colors.
  ///
  /// * < 80% → success
  /// * 80–100% → warning
  /// * > 100% → error
  static Color colorFor(
    double utilization, {
    Color? successColor,
    Color? warningColor,
    Color? errorColor,
  }) {
    final success = successColor ?? const Color(0xFF239B70);
    final warning = warningColor ?? const Color(0xFFD89432);
    final error = errorColor ?? const Color(0xFFD65C62);
    if (utilization >= 1.0) return error;
    if (utilization >= 0.8) return warning;
    return success;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = context.appColors;
    final clamped = value.clamp(0.0, 1.0);
    final color = colorFor(
      value,
      successColor: appColors.success,
      warningColor: appColors.warning,
      errorColor: appColors.error,
    );
    final percentage = (value * 100).clamp(0.0, 100.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox.shrink(),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: height,
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
