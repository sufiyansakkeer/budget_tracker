import 'package:flutter/material.dart';

import '../constants/app_motion.dart';

/// Shows dialogs with a Material 3 fade + scale entrance and exit.
///
/// A thin wrapper over [showGeneralDialog] that keeps [showDialog]'s
/// behaviour (captured inherited themes, safe area, root navigator, barrier
/// colour and label) while replacing the plain fade with a gentle
/// scale-and-fade. Respects reduced-motion settings.
class AppDialog {
  AppDialog._();

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    bool useRootNavigator = true,
    bool useSafeArea = true,
    Color? barrierColor,
  }) {
    final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
    final themes = InheritedTheme.capture(from: context, to: navigator.context);
    final reduce = AppMotion.isReduced(context);

    return showGeneralDialog<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor:
          barrierColor ??
          DialogTheme.of(context).barrierColor ??
          Colors.black54,
      transitionDuration: reduce ? Duration.zero : AppMotion.dialog,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        Widget dialog = themes.wrap(Builder(builder: builder));
        if (useSafeArea) dialog = SafeArea(child: dialog);
        return dialog;
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        if (reduce) return child;
        final eased = animation.drive(
          CurveTween(curve: AppMotion.emphasizedDecelerate),
        );
        return FadeTransition(
          opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
          child: ScaleTransition(
            scale: eased.drive(Tween<double>(begin: 0.92, end: 1)),
            child: child,
          ),
        );
      },
    );
  }
}
