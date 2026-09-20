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

/// Container for [StatefulShellRoute] branches that fades between tabs
/// instead of snapping like an [IndexedStack].
///
/// Every branch stays mounted so each tab keeps its scroll position and
/// navigation stack. Inactive branches are fully transparent (skipped at
/// paint time), ignore pointers, are excluded from focus and have their
/// tickers paused, so the cost matches the default indexed stack.
class FadeThroughBranchContainer extends StatelessWidget {
  final int currentIndex;
  final List<Widget> children;

  const FadeThroughBranchContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.respectReducedMotion(
      context,
      AppMotion.standard,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          _Branch(
            active: i == currentIndex,
            duration: duration,
            child: children[i],
          ),
      ],
    );
  }
}

class _Branch extends StatelessWidget {
  final bool active;
  final Duration duration;
  final Widget child;

  const _Branch({
    required this.active,
    required this.duration,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // The implicit animations sit *outside* TickerMode so the outgoing tab
    // can still fade out after its own tickers are paused.
    return AnimatedOpacity(
      opacity: active ? 1 : 0,
      duration: duration,
      curve: active ? Curves.easeOut : Curves.easeIn,
      child: AnimatedScale(
        scale: active ? 1 : 0.98,
        duration: duration,
        curve: AppMotion.standardCurve,
        child: IgnorePointer(
          ignoring: !active,
          child: ExcludeFocus(
            excluding: !active,
            child: TickerMode(enabled: active, child: child),
          ),
        ),
      ),
    );
  }
}
