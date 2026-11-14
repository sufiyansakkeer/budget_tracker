import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';

/// How many frames a cold-start tap waits for the router before giving up.
const int _maxFramesToWait = 600;

/// Opens [route] over the current screen, for a notification tap.
///
/// A tap that launched the app is read before the app is on screen, so
/// this waits until the router has built its navigator (its first location,
/// after the start-up redirect, is resolved). With the app lock on, the
/// screen opens under the lock and shows once unlocked.
void openRouteFromNotification(
  String route, {
  GoRouter? router,
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  final target = router ?? AppRouter.router;
  final key = navigatorKey ?? AppRouter.rootNavigatorKey;
  Future<void> open() async {
    for (var frame = 0; key.currentState == null; frame++) {
      if (frame >= _maxFramesToWait) {
        debugPrint('[error] Opening $route: the app never showed');
        return;
      }
      await SchedulerBinding.instance.endOfFrame;
    }
    try {
      target.push(route);
    } catch (e) {
      debugPrint('[error] Opening $route from a notification: $e');
    }
  }

  unawaited(open());
}

/// The evening summary's tap: the evening review.
void openEveningReviewFromNotification() =>
    openRouteFromNotification(AppRouter.eveningReviewPath);
