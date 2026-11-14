import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../constants/app_motion.dart';
import 'pressable.dart';
import 'app_animated_size.dart';

/// The app's extended floating action button.
///
/// Scales and fades in once when it appears, and presses in slightly when
/// tapped, so the primary action feels alive without competing with the
/// bottom navigation bar. Reduced-motion settings skip the entrance.
class AppFab extends StatelessWidget {
  final Object heroTag;
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final String? tooltip;

  /// Plays the scale-and-fade entrance on first build. Pass false when the
  /// button is added to a [Scaffold] after its first frame: the scaffold
  /// then animates the button in itself and a second entrance would stack.
  final bool animateEntrance;

  /// Shows the label. Ignored when [collapse] is given.
  final bool extended;

  /// Folds the label away while the user scrolls the screen's list down and
  /// brings it back on the way up, so the button covers less of the
  /// right-aligned amounts. Every list screen with an extended FAB uses one;
  /// wrap the body in [AppFabCollapse.listen].
  final AppFabCollapse? collapse;

  const AppFab({
    super.key,
    required this.heroTag,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.tooltip,
    this.animateEntrance = true,
    this.extended = true,
    this.collapse,
  });

  @override
  Widget build(BuildContext context) {
    final collapse = this.collapse;
    if (collapse == null) return _build(context, extended);
    return ValueListenableBuilder<bool>(
      valueListenable: collapse,
      builder: (context, extended, _) => _build(context, extended),
    );
  }

  Widget _build(BuildContext context, bool extended) {
    final fab = Pressable(
      enabled: onPressed != null,
      pressedScale: AppMotion.pressedScale,
      child: FloatingActionButton.extended(
        heroTag: heroTag,
        onPressed: onPressed,
        icon: Icon(icon),
        // The label folds away instead of snapping, so the button shrinks to
        // its icon in one movement.
        label: AppAnimatedSize(
          duration: AppMotion.respectReducedMotion(context, AppMotion.standard),
          curve: AppMotion.standardCurve,
          child: extended ? Text(label) : const SizedBox.shrink(),
        ),
        extendedIconLabelSpacing: extended ? null : 0,
        tooltip: tooltip ?? label,
      ),
    );

    if (!animateEntrance || AppMotion.isReduced(context)) return fab;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppMotion.medium,
      curve: AppMotion.emphasizedDecelerate,
      child: fab,
      builder: (context, t, child) {
        if (t >= 1) return child!;
        return Transform.scale(
          scale: 0.8 + 0.2 * t,
          child: Opacity(opacity: t, child: child),
        );
      },
    );
  }
}

/// Whether an [AppFab] shows its label: true at rest, false while the user
/// scrolls the list down, true again as soon as they scroll back up.
///
/// The FAB sits outside the scroll view, so the screen owns one, listens to
/// its body with [listen] and passes it to [AppFab.collapse]. Only the button
/// rebuilds on a change, never the screen. Horizontal lists (chip rows,
/// carousels) are ignored. Dispose it with the screen's state.
class AppFabCollapse extends ValueNotifier<bool> {
  AppFabCollapse() : super(true);

  /// Whether the label is showing.
  bool get extended => value;

  /// Updates [extended] from a user scroll. Never stops the notification.
  bool onUserScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    switch (notification.direction) {
      case ScrollDirection.reverse:
        value = false;
      case ScrollDirection.forward:
        value = true;
      case ScrollDirection.idle:
        // Back at the top (a pull to refresh, a fling home) the label
        // returns, so it is never stuck folded on a list that stopped
        // scrolling.
        final m = notification.metrics;
        if (m.pixels <= m.minScrollExtent) value = true;
    }
    return false;
  }

  /// Wraps a screen body so its scrolling drives the button.
  Widget listen({required Widget child}) =>
      NotificationListener<UserScrollNotification>(
        onNotification: onUserScroll,
        child: child,
      );
}
