import 'package:flutter/material.dart';

/// The app's one way to show a snackbar, with one duration policy:
///
/// * a plain message stays [messageDuration] (4 s);
/// * one with an action (Undo, Retry, Make active) stays [actionDuration]
///   (6 s), so there is time to reach the button.
///
/// A new snackbar always replaces the one on screen rather than queueing
/// behind it, so the message shown is about what the user just did.
/// Placement comes from the theme (`snackBarTheme`, which `AppShell` lifts
/// above a tab's add button).
abstract final class AppSnack {
  /// How long a message without an action stays on screen.
  static const Duration messageDuration = Duration(seconds: 4);

  /// How long a message with an action stays on screen.
  static const Duration actionDuration = Duration(seconds: 6);

  /// The snackbar [show] shows, for a caller that needs the [SnackBar]
  /// itself (to choose between two, say). [actionLabel] and [onAction] go
  /// together.
  static SnackBar bar(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Key? key,
    Key? actionKey,
  }) {
    assert(
      (actionLabel == null) == (onAction == null),
      'actionLabel and onAction go together',
    );
    final hasAction = actionLabel != null && onAction != null;
    return SnackBar(
      key: key,
      content: Text(message),
      duration: hasAction ? actionDuration : messageDuration,
      action: hasAction
          ? SnackBarAction(
              key: actionKey,
              label: actionLabel,
              onPressed: onAction,
            )
          : null,
    );
  }

  /// Shows [message] on the nearest [ScaffoldMessenger] of [context],
  /// replacing the current snackbar.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Key? key,
    Key? actionKey,
  }) => showOn(
    ScaffoldMessenger.of(context),
    message,
    actionLabel: actionLabel,
    onAction: onAction,
    key: key,
    actionKey: actionKey,
  );

  /// [show] for a messenger captured before an `await` or before the
  /// screen closed.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showOn(
    ScaffoldMessengerState messenger,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Key? key,
    Key? actionKey,
  }) => present(
    messenger,
    bar(
      message,
      actionLabel: actionLabel,
      onAction: onAction,
      key: key,
      actionKey: actionKey,
    ),
  );

  /// Replaces the current snackbar with [snackBar] (one built by [bar]).
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> present(
    ScaffoldMessengerState messenger,
    SnackBar snackBar,
  ) {
    messenger.hideCurrentSnackBar();
    return messenger.showSnackBar(snackBar);
  }
}
