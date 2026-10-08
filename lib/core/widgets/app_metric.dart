import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../theme/app_typography.dart';

/// A small label over a value: "Spent today / ₹570".
///
/// One anatomy for every figure-with-a-label in the app: the label in the
/// eyebrow role and a muted colour, the [value] (usually an `AppMoney`)
/// beneath it, and an optional [help] line under that. Read by screen
/// readers as one phrase, "label, value".
class AppMetric extends StatelessWidget {
  final String label;
  final Widget value;
  final String? help;

  /// Right-align, for the trailing metric of a pair.
  final bool alignEnd;

  /// Colour for the label; defaults to `onSurfaceVariant`.
  final Color? labelColor;

  const AppMetric({
    super.key,
    required this.label,
    required this.value,
    this.help,
    this.alignEnd = false,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = labelColor ?? theme.colorScheme.onSurfaceVariant;
    final align = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textAlign = alignEnd ? TextAlign.end : TextAlign.start;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: align,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: context.appTypography.eyebrow.copyWith(color: muted),
            textAlign: textAlign,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xxs),
          value,
          if (help != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              help!,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
              textAlign: textAlign,
            ),
          ],
        ],
      ),
    );
  }
}
