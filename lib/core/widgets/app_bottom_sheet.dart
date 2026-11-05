import 'package:flutter/material.dart';

import '../constants/app_motion.dart';
import '../constants/app_spacing.dart';

/// Convenience helper for showing a consistent modal bottom sheet.
///
/// Every sheet respects the top safe area, resizes above the keyboard and can
/// always be dismissed by dragging the handle (a form can ask first, see
/// [show]'s `confirmClose`). The content sits inside a bottom-only [SafeArea]
/// *within* the sheet, so the drag gesture (owned by the sheet itself) is
/// never intercepted.
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
  ///
  /// [confirmClose], when given, runs before the sheet closes without a
  /// result (a swipe down, back, a tap outside), and the sheet closes only
  /// if it completes with true: a form uses it to ask before discarding what
  /// was typed. [PopScope] can't do this, as a swipe pops the sheet
  /// directly.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    bool showDragHandle = true,
    bool useSafeArea = true,
    bool isDismissible = true,
    bool useRootNavigator = true,
    Future<bool> Function()? confirmClose,
  }) {
    final animationStyle = AnimationStyle(
      duration: AppMotion.respectReducedMotion(context, AppMotion.sheet),
      reverseDuration: AppMotion.respectReducedMotion(
        context,
        AppMotion.sheetExit,
      ),
    );
    Widget content(BuildContext sheetContext) {
      // The keyboard inset already changes frame by frame as the keyboard
      // slides; animating it again would make the sheet trail behind.
      final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(top: false, child: builder(sheetContext)),
      );
    }

    if (confirmClose == null) {
      return showModalBottomSheet<T>(
        context: context,
        useRootNavigator: useRootNavigator,
        isScrollControlled: isScrollControlled,
        showDragHandle: showDragHandle,
        useSafeArea: useSafeArea,
        isDismissible: isDismissible,
        enableDrag: true,
        sheetAnimationStyle: animationStyle,
        builder: content,
      );
    }

    // The route showModalBottomSheet pushes, with the close guard.
    final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
    final localizations = MaterialLocalizations.of(context);
    return navigator.push(
      _GuardedSheetRoute<T>(
        confirmClose: confirmClose,
        builder: content,
        capturedThemes: InheritedTheme.capture(
          from: context,
          to: navigator.context,
        ),
        isScrollControlled: isScrollControlled,
        barrierLabel: localizations.scrimLabel,
        barrierOnTapHint: localizations.scrimOnTapHint(
          localizations.bottomSheetLabel,
        ),
        modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
        isDismissible: isDismissible,
        showDragHandle: showDragHandle,
        useSafeArea: useSafeArea,
        sheetAnimationStyle: animationStyle,
      ),
    );
  }
}

/// A sheet that runs [confirmClose] before closing without a result.
///
/// Every way of closing a sheet ends in [didPop]: a swipe or a tap on the
/// handle pops it directly, back and a tap outside through
/// [Navigator.maybePop]. Returning false there keeps the route.
class _GuardedSheetRoute<T> extends ModalBottomSheetRoute<T> {
  final Future<bool> Function() confirmClose;
  bool _asking = false;
  bool _closeConfirmed = false;

  _GuardedSheetRoute({
    required this.confirmClose,
    required super.builder,
    required super.capturedThemes,
    required super.isScrollControlled,
    required super.barrierLabel,
    required super.barrierOnTapHint,
    required super.modalBarrierColor,
    required super.isDismissible,
    required super.showDragHandle,
    required super.useSafeArea,
    required super.sheetAnimationStyle,
  });

  @override
  bool didPop(T? result) {
    if (result != null || _closeConfirmed) return super.didPop(result);
    if (!_asking) _ask();
    return false;
  }

  Future<void> _ask() async {
    _asking = true;
    // didPop runs while the navigator is mid-update: ask after it.
    final close = await Future.microtask(confirmClose);
    _asking = false;
    if (!isActive) return;
    if (close) {
      _closeConfirmed = true;
      isCurrent ? navigator!.pop() : navigator!.removeRoute(this);
    } else {
      // A swipe had already started sliding the sheet away.
      controller!.forward();
    }
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
