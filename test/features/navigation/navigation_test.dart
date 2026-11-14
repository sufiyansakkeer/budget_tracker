import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/navigation/animated_bottom_navigation.dart';
import 'package:monivo/core/navigation/app_nav_destinations.dart';
import 'package:monivo/core/router/app_shell.dart';

void main() {
  group('AppShell Bottom Navigation', () {
    late GoRouter router;
    late int adds;
    late int holds;

    // Branch order as in app_router.dart.
    const paths = ['home', 'budgets', 'expenses', 'reports', 'settings'];

    Widget buildShell() {
      adds = 0;
      holds = 0;
      router = GoRouter(
        initialLocation: '/app/home',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) => AppShell(
              navigationShell: navigationShell,
              onAdd: (_) => adds++,
              onAddHold: (_) => holds++,
            ),
            branches: [
              for (final path in paths)
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/app/$path',
                      builder: (_, _) => _FakePage(path),
                    ),
                  ],
                ),
            ],
          ),
        ],
      );
      return MaterialApp.router(routerConfig: router);
    }

    AnimatedBottomNavigation bar(WidgetTester tester) =>
        tester.widget<AnimatedBottomNavigation>(
          find.byType(AnimatedBottomNavigation),
        );

    testWidgets('one bar: Today, Budget, Activity, More', (tester) async {
      await tester.pumpWidget(buildShell());
      await tester.pump();

      expect(find.byType(AnimatedBottomNavigation), findsOneWidget);
      final labels = bar(tester).destinations.map((d) => d.label).toList();
      expect(labels, ['Today', 'Budget', 'Activity', 'More']);
      for (final d in appNavDestinations) {
        expect(find.byKey(d.key), findsOneWidget);
        expect(find.text(d.label), findsOneWidget);
      }
    });

    testWidgets('the add button sits between Budget and Activity', (
      tester,
    ) async {
      await tester.pumpWidget(buildShell());
      await tester.pump();

      final add = tester.getCenter(find.byKey(const Key('nav_add')));
      final budget = tester.getCenter(find.byKey(appNavDestinations[1].key));
      final activity = tester.getCenter(find.byKey(appNavDestinations[2].key));
      expect(add.dx, greaterThan(budget.dx));
      expect(add.dx, lessThan(activity.dx));
    });

    testWidgets('the + is raised: it rises above the bar (blueprint)', (
      tester,
    ) async {
      await tester.pumpWidget(buildShell());
      await tester.pump();

      final add = tester.getRect(find.byKey(const Key('nav_add')));
      final bar = tester.getRect(find.byType(AnimatedBottomNavigation));
      expect(add.top, lessThan(bar.top));
      expect(add.bottom, greaterThan(bar.top));
      // A 56dp square inside a ring of the bar's colour.
      expect(add.width, 64);
      expect(add.height, 64);
    });

    testWidgets('starts on Today', (tester) async {
      await tester.pumpWidget(buildShell());
      await tester.pump();

      expect(bar(tester).selectedIndex, 0);
      expect(find.text('home'), findsOneWidget);
    });

    for (final (tab, page) in const [
      (1, 'budgets'),
      (2, 'expenses'),
      (3, 'settings'),
    ]) {
      testWidgets('tab $tab opens $page', (tester) async {
        await tester.pumpWidget(buildShell());
        await tester.pump();

        await tester.tap(find.byKey(appNavDestinations[tab].key));
        await tester.pumpAndSettle();

        expect(bar(tester).selectedIndex, tab);
        expect(find.text(page), findsOneWidget);
      });
    }

    testWidgets('Insights shows Activity selected; Activity goes back', (
      tester,
    ) async {
      await tester.pumpWidget(buildShell());
      await tester.pump();

      router.go('/app/reports');
      await tester.pumpAndSettle();
      expect(find.text('reports'), findsOneWidget);
      expect(bar(tester).selectedIndex, 2);

      await tester.tap(find.byKey(appNavDestinations[2].key));
      await tester.pumpAndSettle();
      expect(find.text('expenses'), findsOneWidget);
      expect(bar(tester).selectedIndex, 2);
    });

    testWidgets('tapping + adds; holding + goes straight to an expense', (
      tester,
    ) async {
      await tester.pumpWidget(buildShell());
      await tester.pump();

      await tester.tap(find.byKey(const Key('nav_add')));
      await tester.pump();
      expect((adds, holds), (1, 0));

      await tester.longPress(find.byKey(const Key('nav_add')));
      await tester.pump();
      expect((adds, holds), (1, 1));
      // Neither changes the tab.
      expect(bar(tester).selectedIndex, 0);
    });

    testWidgets('can cycle through all tabs and settles', (tester) async {
      await tester.pumpWidget(buildShell());
      await tester.pump();

      for (final id in ['budget', 'activity', 'more', 'today']) {
        await tester.tap(find.byKey(Key('nav_$id')));
        await tester.pumpAndSettle();
      }

      expect(bar(tester).selectedIndex, 0);
    });

    testWidgets('re-tapping the current tab keeps it selected', (tester) async {
      await tester.pumpWidget(buildShell());
      await tester.pump();

      await tester.tap(find.byKey(appNavDestinations[0].key));
      await tester.pumpAndSettle();

      expect(bar(tester).selectedIndex, 0);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('exposes selected state and the add button\'s name', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildShell());
      await tester.pump();

      final today = tester.getSemantics(find.byKey(appNavDestinations[0].key));
      expect(today.hasFlag(SemanticsFlag.isSelected), isTrue);
      expect(today.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(today.label, contains('Today'));

      final activity = tester.getSemantics(
        find.byKey(appNavDestinations[2].key),
      );
      expect(activity.hasFlag(SemanticsFlag.isSelected), isFalse);

      expect(
        find.bySemanticsLabel(RegExp(r'^Add$')),
        findsOneWidget,
        reason: 'the + is announced as "Add"',
      );
      handle.dispose();
    });
  });
}

class _FakePage extends StatelessWidget {
  final String label;
  const _FakePage(this.label);

  @override
  Widget build(BuildContext context) => Center(child: Text(label));
}
