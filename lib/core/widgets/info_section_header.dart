import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import 'info_content.dart';
import 'info_icon.dart';

/// A section header with an optional info icon.
///
/// Drop-in replacement for [SectionHeader] when you also want an info icon.
/// The info icon is placed at the trailing end (top-right of the header).
class InfoSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final InfoContent? infoContent;

  const InfoSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.infoContent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (infoContent != null) InfoIcon(content: infoContent!),
          if (trailing != null) ...[
            if (infoContent != null) const SizedBox(width: AppSpacing.xs),
            trailing!,
          ],
        ],
      ),
    );
  }
}
