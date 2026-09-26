import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/navigation/animated_bottom_navigation.dart';
import 'package:monivo/core/navigation/app_nav_destinations.dart';
import 'package:monivo/core/navigation/nav_icon_mode.dart';
import 'package:monivo/core/router/app_shell.dart';

void main() {
  group('AppShell Bottom Navigation', () {
    Widget buildShell() {
      final branches = [
        for (final path in ['home', 'expenses', 'reports', 'settings'])
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/app/$path', builder: (_, __) => _FakePage(path)),
            ],
          ),
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

      // The Rive runtime cannot run inside `flutter test`; render Material
      // icons instead. Everything else about the bar is exercised for real.
      return NavIconMode(
        renderer: NavIconRenderer.material,
        child: MaterialApp.router(routerConfig: router),
      );
    }

    AnimatedBottomNavigation bar(WidgetTester tester) =>
        tester.widget<AnimatedBottomNavigation>(
          find.byType(AnimatedBottomNavigation),
        );

    testWidgets('renders exactly one bar with 4 destinations', (tester) async {
      await tester.pumpWidget(buildShell());
      await tester.pump();

      expect(find.byType(AnimatedBottomNavigation), findsOneWidget);
      expect(bar(tester).destinations.length, 4);
      for (final d in appNavDestinations) {
        expect(find.byKey(d.key), findsOneWidget);
      }
    });

    testWidgets('displays Home, Expenses, Reports, Settings labels in order', (
      tester,
    ) async {
      await tester.pumpWidget(buildShell());
      await tester.pump();

      final labels = bar(tester).destinations.map((d) => d.label).toList();
      expect(labels, ['Home', 'Expenses', 'Reports', 'Settings']);
      for (final label in labels) {
        expect(find.text(label), findsAtLeastNWidgets(1));
      }
    });

    testWidgets('does NOT expose Budget or Bills as tabs', (tester) async {
      await tester.pumpWidget(buildShell());
      await tester.pump();

      final labels = bar(tester).destinations.map((d) => d.label).toList();
      expect(labels, isNot(contains('Budget')));
      expect(labels, isNot(contains('Bills')));
    });

    testWidgets('starts on Home tab (index 0)', (tester) async {
      await tester.pumpWidget(buildShell());
      await tester.pump();

      expect(bar(tester).selectedIndex, 0);
      expect(find.text('home'), findsOneWidget);
    });

    for (final (index, label) in const [
      (1, 'Expenses'),
      (2, 'Reports'),
      (3, 'Settings'),
    ]) {
      testWidgets('navigates to $label tab on tap', (tester) async {
        await tester.pumpWidget(buildShell());
        await tester.pump();

        await tester.tap(find.byKey(appNavDestinations[index].key));
        await tester.pumpAndSettle();

        expect(bar(tester).selectedIndex, index);
        expect(find.text(label.toLowerCase()), findsOneWidget);
      });
    }

    testWidgets('can cycle through all 4 tabs and settles', (tester) async {
      await tester.pumpWidget(buildShell());
      await tester.pump();

      for (final id in ['expenses', 'reports', 'settings', 'home']) {
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

    testWidgets('exposes selected state to assistive technology', (
      tester,
    ) async {
      await tester.pumpWidget(buildShell());
      await tester.pump();

      final home = tester.getSemantics(find.byKey(appNavDestinations[0].key));
      expect(home.hasFlag(SemanticsFlag.isSelected), isTrue);
      expect(home.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(home.label, contains('Home'));

      final reports = tester.getSemantics(
        find.byKey(appNavDestinations[2].key),
      );
      expect(reports.hasFlag(SemanticsFlag.isSelected), isFalse);
    });
  });
}

class _FakePage extends StatelessWidget {
  final String label;
  const _FakePage(this.label);

  @override
  Widget build(BuildContext context) => Center(child: Text(label));
}
