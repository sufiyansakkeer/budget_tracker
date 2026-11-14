import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/router/open_route_from_notification.dart';

/// Opens [tabId]'s screen over the current one, for a tap on its settle-up
/// reminder; see [openRouteFromNotification] for a tap that launched the
/// app.
void openTabFromNotification(
  String tabId, {
  GoRouter? router,
  GlobalKey<NavigatorState>? navigatorKey,
}) => openRouteFromNotification(
  '${AppRouter.payLaterPath}/$tabId',
  router: router,
  navigatorKey: navigatorKey,
);
