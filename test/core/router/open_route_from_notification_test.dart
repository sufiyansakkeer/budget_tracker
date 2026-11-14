import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/router/app_router.dart';
import 'package:monivo/core/router/open_route_from_notification.dart';

void main() {
  late GlobalKey<NavigatorState> navigatorKey;
  late GoRouter router;

  setUp(() {
    navigatorKey = GlobalKey<NavigatorState>();
    router = GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: AppRouter.homePath,
      routes: [
        GoRoute(
          path: AppRouter.homePath,
          builder: (context, state) => const Text('home'),
        ),
        GoRoute(
          path: AppRouter.eveningReviewPath,
          builder: (context, state) => const Text('review'),
        ),
      ],
    );
  });

  tearDown(() => router.dispose());

  testWidgets('a cold-start tap waits for the router, then opens the route '
      'over home', (tester) async {
    openRouteFromNotification(
      AppRouter.eveningReviewPath,
      router: router,
      navigatorKey: navigatorKey,
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('review'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });
}
