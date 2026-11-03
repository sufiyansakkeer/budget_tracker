import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';

/// How many frames a cold-start tap waits for the router before giving up.
const int _maxFramesToWait = 600;

/// Opens [tabId]'s screen over the current one, for a tap on its settle-up
/// reminder.
///
/// A tap that launched the app is read before the app is on screen, so
/// this waits until the router has built its navigator (its first location,
/// after the start-up redirect, is resolved). With the app lock on, the
/// screen opens under the lock and shows once unlocked.
void openTabFromNotification(
  String tabId, {
  GoRouter? router,
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  final target = router ?? AppRouter.router;
  final key = navigatorKey ?? AppRouter.rootNavigatorKey;
  Future<void> open() async {
    for (var frame = 0; key.currentState == null; frame++) {
      if (frame >= _maxFramesToWait) {
        debugPrint('[error] Opening tab $tabId: the app never showed');
        return;
      }
      await SchedulerBinding.instance.endOfFrame;
    }
    try {
      target.push('${AppRouter.payLaterPath}/$tabId');
    } catch (e) {
      debugPrint('[error] Opening tab $tabId from its reminder: $e');
    }
  }

  unawaited(open());
}
