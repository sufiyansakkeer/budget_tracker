import 'package:flutter/material.dart';

import '../constants/app_motion.dart';
import '../constants/app_spacing.dart';

/// Convenience helper for showing a consistent modal bottom sheet.
///
/// Every sheet respects the top safe area, resizes above the keyboard and can
/// always be dismissed by dragging the handle. The content sits inside a
/// bottom-only [SafeArea] *within* the sheet, so the drag gesture (owned by
/// the sheet itself) is never intercepted.
///
/// Sheets open on the root navigator so they cover the bottom navigation
/// bar (and the tabs cannot be switched underneath an open sheet).
class AppBottomSheet {
  AppBottomSheet._();

  /// Shows a bottom sheet and returns its typed result.
  ///
  /// The [builder]'s content is wrapped so it sits above the keyboard and
  /// inside the bottom safe area. Use [isScrollControlled] (default true) for
  /// sheets whose height depends on content.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    bool showDragHandle = true,
    bool useSafeArea = true,
    bool isDismissible = true,
    bool useRootNavigator = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      isScrollControlled: isScrollControlled,
      showDragHandle: showDragHandle,
      useSafeArea: useSafeArea,
      isDismissible: isDismissible,
      enableDrag: true,
      sheetAnimationStyle: AnimationStyle(
        duration: AppMotion.respectReducedMotion(context, AppMotion.sheet),
        reverseDuration: AppMotion.respectReducedMotion(
          context,
          AppMotion.sheetExit,
        ),
      ),
      builder: (sheetContext) {
        // The keyboard inset already changes frame by frame as the keyboard
        // slides; animating it again would make the sheet trail behind.
        final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SafeArea(top: false, child: builder(sheetContext)),
        );
      },
    );
  }
}

/// Standard title block at the top of a bottom sheet.
class AppSheetHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const AppSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.md,
        AppSpacing.smd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: theme.textTheme.titleLarge),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
