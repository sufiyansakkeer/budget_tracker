import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:monivo/core/router/app_router.dart';
import 'package:monivo/features/pay_later/presentation/open_tab_from_notification.dart';

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
          path: '${AppRouter.payLaterPath}/:id',
          builder: (context, state) =>
              Text('tab ${state.pathParameters['id']}'),
        ),
      ],
    );
  });

  tearDown(() => router.dispose());

  testWidgets('a cold-start tap waits for the router, then opens the tab '
      'over home', (tester) async {
    // The launch details are read before the app is on screen.
    openTabFromNotification('t1', router: router, navigatorKey: navigatorKey);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('tab t1'), findsOneWidget);
    expect(router.state.uri.path, '${AppRouter.payLaterPath}/t1');

    // Back goes to the screen the app opened on.
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a tap while the app is open opens the tab', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    openTabFromNotification('t2', router: router, navigatorKey: navigatorKey);
    await tester.pumpAndSettle();

    expect(find.text('tab t2'), findsOneWidget);
  });
}
