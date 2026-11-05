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

/// Two or three [AppMetric]s side by side with gutters: "Spent / Spent
/// today / Expenses".
///
/// When the text is too large for each metric to get a readable column,
/// they stack instead, so a label never breaks mid-word and two figures
/// never run together into one.
class AppMetricRow extends StatelessWidget {
  final List<AppMetric> metrics;

  const AppMetricRow({super.key, required this.metrics});

  /// The narrowest column, before text scaling, that a metric keeps before
  /// the row stacks: "Daily average" in the eyebrow style at 100%.
  static const double minColumnWidth = 80;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = metrics.length;
        final column = (constraints.maxWidth - AppSpacing.md * (n - 1)) / n;
        if (column >= scaler.scale(minColumnWidth)) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < n; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.md),
                Expanded(child: metrics[i]),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              // Stacked, every metric starts at the same edge.
              AppMetric(
                key: metrics[i].key,
                label: metrics[i].label,
                value: metrics[i].value,
                help: metrics[i].help,
                labelColor: metrics[i].labelColor,
              ),
            ],
          ],
        );
      },
    );
  }
}
