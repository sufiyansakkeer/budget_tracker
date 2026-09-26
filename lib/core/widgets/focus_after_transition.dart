import 'package:flutter/widgets.dart';

/// Focuses [node] once the enclosing route has finished animating in.
///
/// A field that `autofocus`es opens the keyboard on the first frame, so the
/// screen resizes while the page transition is still playing. Call this
/// from `initState` (it defers to after the first frame itself) instead.
/// Routes without a transition (reduced motion) focus immediately.
void requestFocusAfterTransition(BuildContext context, FocusNode node) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      node.requestFocus();
      return;
    }
    void listener(AnimationStatus status) {
      if (status != AnimationStatus.completed) return;
      animation.removeStatusListener(listener);
      // Skip if the field is gone, or the user already focused another one.
      if (node.context == null) return;
      final current = FocusManager.instance.primaryFocus;
      if (current == null || current is FocusScopeNode) node.requestFocus();
    }

    animation.addStatusListener(listener);
  });
}
