import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/info_content.dart';
import '../../../../core/widgets/info_icon.dart';

/// Shared frame for every chart on the reports screen: a section title,
/// an optional one-line answer ("what does this chart tell me"), an
/// optional info icon and the chart itself. Flat, like every other section
/// in the redesign: the report reads as one page, not a stack of cards.
class ChartCard extends StatelessWidget {
  final String title;
  final String? caption;
  final InfoContent? info;
  final Widget child;
  final Widget? trailing;

  const ChartCard({
    super.key,
    required this.title,
    this.caption,
    this.info,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (info != null) InfoIcon(content: info!),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
        if (caption != null)
          Text(
            caption!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}

/// Placeholder shown inside a chart card when there isn't enough data.
class ChartPlaceholder extends StatelessWidget {
  final IconData icon;
  final String message;

  const ChartPlaceholder({
    super.key,
    this.icon = Icons.show_chart_rounded,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: AppSizes.chartHeightSm,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppSizes.iconXl,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
