import 'package:flutter/material.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_animated_size.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/widgets/app_list.dart';

/// A labelled group of settings rows.
///
/// A header (blueprint .sh: title 17/700, optional description) over rows
/// that sit flat on the page, separated by hairlines that start where the
/// row text starts. The group sets the gap after each row's leading tile, so
/// every row inside lines up whatever widget draws it (see [SettingsTile]).
class SettingsSection extends StatelessWidget {
  final String title;
  final String? description;
  final List<Widget> children;

  /// Shows a thin progress line above the rows while the group's action
  /// runs (an export, a restore).
  final bool busy;

  /// The gap between a row's leading tile and its text (blueprint: 16).
  static const double leadingGap = AppSpacing.md;

  /// Hairlines start under the row text, past the leading tile.
  static const double dividerIndent = AppSizes.avatarSm + leadingGap;

  const SettingsSection({
    super.key,
    required this.title,
    this.description,
    required this.children,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = context.appColors.textTertiary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // Blueprint .sh: the rows sit on the page, so the header lines
          // up with them at the gutter.
          padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (description != null)
                Text(
                  description!,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
            ],
          ),
        ),
        AppAnimatedSize(
          duration: AppMotion.respectReducedMotion(context, AppMotion.fast),
          alignment: Alignment.topCenter,
          child: busy
              ? Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: LinearProgressIndicator(
                    minHeight: AppSizes.progressThin,
                    borderRadius: AppSpacing.borderRadiusXs,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        ListTileTheme.merge(
          contentPadding: EdgeInsets.zero,
          horizontalTitleGap: leadingGap,
          minLeadingWidth: AppSizes.avatarSm,
          child: AppGroupedList(
            dividerIndent: dividerIndent,
            children: children,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}
