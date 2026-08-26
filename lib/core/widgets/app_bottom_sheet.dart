import 'package:flutter/material.dart';

/// Convenience helper for showing a consistent modal bottom sheet.
class AppBottomSheet {
  AppBottomSheet._();

  /// Shows a bottom sheet and returns its typed result.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    bool showDragHandle = true,
    bool useSafeArea = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      showDragHandle: showDragHandle,
      useSafeArea: useSafeArea,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: builder,
    );
  }
}
