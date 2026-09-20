import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_spacing.dart';

/// A consistent page header showing the screen title and a contextual
/// subtitle, used by tab screens that have no [AppBar].
class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool centerTitle;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: centerTitle
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Formats a date range like "1 Aug – 31 Aug 2026".
String formatDateRange(DateTime start, DateTime end) {
  final sameYear = start.year == end.year;
  final startFmt = sameYear ? DateFormat('d MMM') : DateFormat('d MMM yyyy');
  final endFmt = DateFormat('d MMM yyyy');
  return '${startFmt.format(start)} – ${endFmt.format(end)}';
}

/// Formats a short date range like "1 Aug – 31 Aug" (no year).
String formatShortDateRange(DateTime start, DateTime end) {
  final fmt = DateFormat('d MMM');
  return '${fmt.format(start)} – ${fmt.format(end)}';
}
