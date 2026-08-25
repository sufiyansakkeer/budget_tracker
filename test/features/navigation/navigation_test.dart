import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/router/app_shell.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('AppShell Bottom Navigation', () {
    Widget buildShell(int index) {
      final branches = [
        StatefulShellBranch(routes: [
          GoRoute(path: '/app/home', builder: (_, __) => const _FakePage('Home')),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/app/reports', builder: (_, __) => const _FakePage('Reports')),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/app/budgets', builder: (_, __) => const _FakePage('Budget')),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/app/settings', builder: (_, __) => const _FakePage('Settings')),
        ]),
      ];

      final router = GoRouter(
        initialLocation: '/app/home',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) =>
                AppShell(navigationShell: navigationShell),
            branches: branches,
          ),
        ],
      );

      return MaterialApp.router(routerConfig: router);
    }

    testWidgets('has exactly 4 NavigationDestination widgets', (tester) async {
      await tester.pumpWidget(buildShell(0));
      await tester.pump();

      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.destinations.length, 4);
    });

    testWidgets('displays Home, Reports, Budget, Settings labels', (tester) async {
      await tester.pumpWidget(buildShell(0));
      await tester.pump();

      // NavigationBar may render duplicate label widgets (selected/unselected)
      // so we check for at least one of each
      expect(find.text('Home'), findsAtLeastNWidgets(1));
      expect(find.text('Reports'), findsAtLeastNWidgets(1));
      expect(find.text('Budget'), findsAtLeastNWidgets(1));
      expect(find.text('Settings'), findsAtLeastNWidgets(1));
    });

    testWidgets('does NOT display Expenses or Bills labels', (tester) async {
      await tester.pumpWidget(buildShell(0));
      await tester.pump();

      // Verify none of the removed tabs appear in the NavigationBar
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      final labels = navBar.destinations
          .map((d) => (d as NavigationDestination).label)
          .toList();

      expect(labels, isNot(contains('Expenses')));
      expect(labels, isNot(contains('Bills')));
    });

    testWidgets('starts on Home tab (index 0)', (tester) async {
      await tester.pumpWidget(buildShell(0));
      await tester.pump();

      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 0);
    });

    testWidgets('navigates to Reports tab on tap', (tester) async {
      await tester.pumpWidget(buildShell(0));
      await tester.pump();

      await tester.tap(find.text('Reports').last);
      await tester.pumpAndSettle();

      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 1);
    });

    testWidgets('navigates to Budget tab on tap', (tester) async {
      await tester.pumpWidget(buildShell(0));
      await tester.pump();

      await tester.tap(find.text('Budget').last);
      await tester.pumpAndSettle();

      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 2);
    });

    testWidgets('navigates to Settings tab on tap', (tester) async {
      await tester.pumpWidget(buildShell(0));
      await tester.pump();

      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();

      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 3);
    });

    testWidgets('can cycle through all 4 tabs', (tester) async {
      await tester.pumpWidget(buildShell(0));
      await tester.pump();

      // Home -> Reports
      await tester.tap(find.text('Reports').last);
      await tester.pumpAndSettle();

      // Reports -> Budget
      await tester.tap(find.text('Budget').last);
      await tester.pumpAndSettle();

      // Budget -> Settings
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();

      // Settings -> Home
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();

      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 0);
    });
  });
}

class _FakePage extends StatelessWidget {
  final String label;
  const _FakePage(this.label);

  @override
  Widget build(BuildContext context) => Center(child: Text(label));
}
