import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Navigation helpers that tolerate rapid taps.
extension PushUnique on BuildContext {
  /// Pushes [location] unless it is already the top of the navigation stack.
  ///
  /// A second tap on a card or FAB while its screen is still animating in
  /// would otherwise push the same page twice, stacking two forms the user
  /// then has to back out of. When the push is skipped the returned future
  /// completes with `null`, like a page that was popped without a result.
  Future<T?> pushUnique<T extends Object?>(String location, {Object? extra}) {
    final router = GoRouter.of(this);
    final current = router.routerDelegate.currentConfiguration.uri.toString();
    if (current == location) return Future<T?>.value(null);
    return router.push<T>(location, extra: extra);
  }
}
