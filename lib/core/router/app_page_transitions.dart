import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_motion.dart';

/// The kinds of screen change the app makes, each with its own motion.
///
/// * [sharedAxisHorizontal] — drilling into a detail or list screen: the new
///   page slides in a little from the right while the old one eases left.
/// * [sharedAxisVertical] — a step "down" in a flow: slides up slightly.
/// * [fadeScale] — a modal-like screen (add/edit forms): fades and scales in
///   over the current screen, which stays put.
/// * [fadeThrough] — switching between peers (bottom-navigation tabs).
enum AppTransition {
  sharedAxisHorizontal,
  sharedAxisVertical,
  fadeScale,
  fadeThrough,
}

/// Builds go_router pages and imperative routes with the app's transitions.
///
/// Durations are short ([AppMotion.page] in, [AppMotion.standard] out) and
/// every transition collapses to an instant switch when the platform asks
/// for reduced motion.
class AppPageTransitions {
  AppPageTransitions._();

  /// A [Page] for a [GoRoute.pageBuilder].
  static Page<T> page<T>({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
    AppTransition transition = AppTransition.sharedAxisHorizontal,
  }) {
    final reduce = AppMotion.isReduced(context);
    return CustomTransitionPage<T>(
      key: state.pageKey,
      name: state.name ?? state.path,
      arguments: state.pathParameters,
      restorationId: state.pageKey.value,
      child: child,
      transitionDuration: reduce ? Duration.zero : AppMotion.page,
      reverseTransitionDuration: reduce ? Duration.zero : AppMotion.standard,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (reduce) return child;
        return buildTransition(
          transition,
          animation,
          secondaryAnimation,
          child,
        );
      },
    );
  }

  /// A [PageRoute] for imperative `Navigator.push` calls.
  static PageRoute<T> route<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    AppTransition transition = AppTransition.sharedAxisHorizontal,
  }) {
    final reduce = AppMotion.isReduced(context);
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionDuration: reduce ? Duration.zero : AppMotion.page,
      reverseTransitionDuration: reduce ? Duration.zero : AppMotion.standard,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (reduce) return child;
        return buildTransition(
          transition,
          animation,
          secondaryAnimation,
          child,
        );
      },
    );
  }

  /// Applies [transition] to [child].
  ///
  /// [animation] drives this page entering/leaving; [secondaryAnimation]
  /// drives this page being covered/uncovered by the next one.
  static Widget buildTransition(
    AppTransition transition,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    switch (transition) {
      case AppTransition.sharedAxisHorizontal:
        return _sharedAxis(
          animation,
          secondaryAnimation,
          child,
          enterFrom: const Offset(0.08, 0),
          exitTo: const Offset(-0.08, 0),
        );
      case AppTransition.sharedAxisVertical:
        return _sharedAxis(
          animation,
          secondaryAnimation,
          child,
          enterFrom: const Offset(0, 0.08),
          exitTo: const Offset(0, -0.04),
        );
      case AppTransition.fadeScale:
        final eased = animation.drive(
          CurveTween(curve: AppMotion.emphasizedDecelerate),
        );
        return FadeTransition(
          opacity: animation.drive(
            CurveTween(curve: const Interval(0, 0.7, curve: Curves.easeOut)),
          ),
          child: ScaleTransition(
            scale: eased.drive(Tween<double>(begin: 0.94, end: 1)),
            child: child,
          ),
        );
      case AppTransition.fadeThrough:
        // Outgoing fades first, incoming fades and settles in after it.
        final incoming = animation.drive(
          CurveTween(curve: const Interval(0.3, 1, curve: Curves.easeOut)),
        );
        final outgoing = ReverseAnimation(
          secondaryAnimation.drive(
            CurveTween(curve: const Interval(0, 0.3, curve: Curves.easeIn)),
          ),
        );
        return FadeTransition(
          opacity: outgoing,
          child: FadeTransition(
            opacity: incoming,
            child: ScaleTransition(
              scale: incoming.drive(Tween<double>(begin: 0.96, end: 1)),
              child: child,
            ),
          ),
        );
    }
  }

  static Widget _sharedAxis(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child, {
    required Offset enterFrom,
    required Offset exitTo,
  }) {
    final enter = animation.drive(
      CurveTween(curve: AppMotion.emphasizedDecelerate),
    );
    final enterFade = animation.drive(
      CurveTween(curve: const Interval(0, 0.6, curve: Curves.easeOut)),
    );
    final cover = secondaryAnimation.drive(
      CurveTween(curve: AppMotion.emphasizedAccelerate),
    );
    final coverFade = ReverseAnimation(
      secondaryAnimation.drive(
        CurveTween(curve: const Interval(0, 0.6, curve: Curves.easeIn)),
      ),
    );

    return SlideTransition(
      position: cover.drive(Tween<Offset>(begin: Offset.zero, end: exitTo)),
      child: FadeTransition(
        opacity: coverFade,
        child: SlideTransition(
          position: enter.drive(
            Tween<Offset>(begin: enterFrom, end: Offset.zero),
          ),
          child: FadeTransition(opacity: enterFade, child: child),
        ),
      ),
    );
  }
}

/// Container for [StatefulShellRoute] branches that plays a Material
/// "fade through" between tabs instead of snapping like an [IndexedStack].
///
/// Every branch stays mounted in its own slot of a [Stack], so each tab keeps
/// its scroll position, navigation stack and BLoCs. Only two branches are
/// ever painted: the one leaving and the one arriving. The outgoing tab fades
/// out during the first third of the transition, then the incoming tab fades
/// in and settles from 96 % to full size. They never overlap at high opacity,
/// so the shell background never shows through as a flash. Every other
/// branch is [Offstage] (kept alive, not painted, not hit-testable).
///
/// Rapid re-targeting (tapping several tabs quickly) starts each new
/// transition from the opacity and scale the tabs currently have, so nothing
/// ever jumps back to fully opaque or fully transparent mid-flight.
///
/// Inactive branches ignore pointers, are excluded from focus and have their
/// tickers paused, so the steady-state cost matches the default indexed
/// stack. Reduced-motion settings switch tabs instantly.
class FadeThroughBranchContainer extends StatefulWidget {
  final int currentIndex;
  final List<Widget> children;

  const FadeThroughBranchContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  /// Fraction of the transition spent fading the outgoing tab out.
  static const double outgoingFraction = 0.35;

  @override
  State<FadeThroughBranchContainer> createState() =>
      _FadeThroughBranchContainerState();
}

class _FadeThroughBranchContainerState extends State<FadeThroughBranchContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.standard,
    value: 1,
  );

  late int _current = widget.currentIndex;
  int? _previous;

  /// Motion of the arriving tab for the transition in flight.
  _BranchMotion _incoming = const _BranchMotion.settled();

  /// Motion of the leaving tab for the transition in flight.
  _BranchMotion _outgoing = const _BranchMotion.hidden();

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _previous != null) {
      setState(() => _previous = null);
    }
  }

  @override
  void didUpdateWidget(covariant FadeThroughBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != _current) _switchTo(widget.currentIndex);
  }

  void _switchTo(int index) {
    if (AppMotion.isReduced(context)) {
      setState(() {
        _previous = null;
        _current = index;
        _incoming = const _BranchMotion.settled();
        _outgoing = const _BranchMotion.hidden();
      });
      _controller.value = 1;
      return;
    }

    final t = _controller.value;
    // Where each slot is *right now*, so a retarget mid-flight continues
    // from the visible state instead of snapping.
    final currentOpacity = _incoming.opacityAt(t);
    final currentScale = _incoming.scaleAt(t);
    final previousOpacity = _outgoing.opacityAt(t);
    final previousScale = _outgoing.scaleAt(t);

    final leaving = _current;
    final wasFadingOut = _previous;

    // If the user bounces straight back to the tab that is still fading out,
    // pick it up from its current opacity rather than from zero.
    final double fromOpacity;
    final double fromScale;
    if (index == wasFadingOut) {
      fromOpacity = previousOpacity;
      fromScale = previousScale;
    } else {
      fromOpacity = 0;
      fromScale = 0.96;
    }

    setState(() {
      _previous = leaving;
      _current = index;
      _outgoing = _BranchMotion(
        opacityFrom: currentOpacity,
        opacityTo: 0,
        scaleFrom: currentScale,
        scaleTo: currentScale,
        curve: const Interval(
          0,
          FadeThroughBranchContainer.outgoingFraction,
          curve: Curves.easeIn,
        ),
      );
      _incoming = _BranchMotion(
        opacityFrom: fromOpacity,
        opacityTo: 1,
        scaleFrom: fromScale,
        scaleTo: 1,
        curve: const Interval(
          FadeThroughBranchContainer.outgoingFraction,
          1,
          curve: Curves.easeOut,
        ),
      );
    });

    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _Branch(
            // Slots keep their position and widget type in every state so a
            // change of role never remounts the branch's Navigator.
            active: i == _current,
            visible: i == _current || i == _previous,
            animation: _controller,
            motion: i == _current
                ? _incoming
                : i == _previous
                ? _outgoing
                : const _BranchMotion.hidden(),
            child: widget.children[i],
          ),
      ],
    );
  }
}

/// Opacity and scale of one branch over a transition, sampled by progress.
class _BranchMotion {
  final double opacityFrom;
  final double opacityTo;
  final double scaleFrom;
  final double scaleTo;
  final Curve curve;

  const _BranchMotion({
    required this.opacityFrom,
    required this.opacityTo,
    required this.scaleFrom,
    required this.scaleTo,
    required this.curve,
  });

  /// Fully visible and at rest.
  const _BranchMotion.settled()
    : this(
        opacityFrom: 1,
        opacityTo: 1,
        scaleFrom: 1,
        scaleTo: 1,
        curve: Curves.linear,
      );

  /// Fully transparent and at rest.
  const _BranchMotion.hidden()
    : this(
        opacityFrom: 0,
        opacityTo: 0,
        scaleFrom: 1,
        scaleTo: 1,
        curve: Curves.linear,
      );

  double opacityAt(double t) =>
      _lerp(opacityFrom, opacityTo, curve.transform(t.clamp(0.0, 1.0)));

  double scaleAt(double t) =>
      _lerp(scaleFrom, scaleTo, curve.transform(t.clamp(0.0, 1.0)));

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

class _Branch extends StatelessWidget {
  final bool active;
  final bool visible;
  final Animation<double> animation;
  final _BranchMotion motion;
  final Widget child;

  const _Branch({
    required this.active,
    required this.visible,
    required this.animation,
    required this.motion,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // The fade/scale sit *outside* TickerMode so the outgoing tab can still
    // animate away after its own tickers are paused. RepaintBoundary keeps
    // the two tabs' repaints independent while both are on screen.
    return Offstage(
      offstage: !visible,
      child: IgnorePointer(
        ignoring: !active,
        child: ExcludeFocus(
          excluding: !active,
          child: AnimatedBuilder(
            animation: animation,
            child: RepaintBoundary(
              child: TickerMode(enabled: active, child: child),
            ),
            // The wrapper structure is identical on every frame (an Opacity
            // of 1 and a scale of 1 are free); swapping wrappers in and out
            // would remount the branch's Navigator.
            builder: (context, child) => Opacity(
              opacity: motion.opacityAt(animation.value),
              child: Transform.scale(
                scale: motion.scaleAt(animation.value),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
