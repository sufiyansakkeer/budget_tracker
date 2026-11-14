import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_fab.dart';

// UX-073: the extended FAB folded on scroll only on Home and Expenses; the
// behaviour now lives in AppFabCollapse, shared by every list screen.
void main() {
  late AppFabCollapse collapse;

  setUp(() => collapse = AppFabCollapse());
  tearDown(() => collapse.dispose());

  Future<void> pump(WidgetTester tester, {Widget? body}) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: collapse.listen(
            child:
                body ??
                ListView(
                  children: [
                    for (var i = 0; i < 40; i++)
                      SizedBox(height: 60, child: Text('Row $i')),
                  ],
                ),
          ),
          floatingActionButton: AppFab(
            heroTag: 'fab',
            onPressed: () {},
            icon: Icons.add_rounded,
            label: 'Add bill',
            collapse: collapse,
            animateEntrance: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final label = find.descendant(
    of: find.byType(FloatingActionButton),
    matching: find.text('Add bill'),
  );

  testWidgets('folds to its icon while scrolling down, back on the way up', (
    tester,
  ) async {
    await pump(tester);
    expect(label, findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(label, findsNothing);
    expect(collapse.extended, isFalse);
    // Still the same action, reachable by its tooltip.
    expect(find.byTooltip('Add bill'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(label, findsOneWidget);
  });

  testWidgets('a horizontal list never folds it', (tester) async {
    await pump(
      tester,
      body: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < 40; i++)
            SizedBox(width: 80, child: Text('Chip $i')),
        ],
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(label, findsOneWidget);
  });

  testWidgets('comes back when a scroll ends at the top, so it is never '
      'stuck folded on a list that can no longer scroll', (tester) async {
    await pump(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(label, findsNothing);

    final context = tester.element(find.byType(ListView));
    UserScrollNotification idleAt(double pixels) => UserScrollNotification(
      metrics: FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 2000,
        pixels: pixels,
        viewportDimension: 640,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1,
      ),
      context: context,
      direction: ScrollDirection.idle,
    );
    // Stopping mid-list keeps it folded...
    collapse.onUserScroll(idleAt(300));
    expect(collapse.extended, isFalse);
    // ...stopping at the top brings the label back.
    collapse.onUserScroll(idleAt(0));
    await tester.pumpAndSettle();
    expect(label, findsOneWidget);
  });

  // UX-073: Expenses (its own setState copy), Categories and Pay later had
  // a FAB that never folded. Every screen's AppFab now takes a collapse.
  test('every AppFab in lib folds on scroll', () {
    final missing = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('core/widgets/app_fab.dart')) continue;
      final source = entity.readAsStringSync();
      var at = source.indexOf('AppFab(');
      while (at >= 0) {
        // The call's own arguments, up to its closing parenthesis.
        var depth = 0;
        var end = at + 'AppFab'.length;
        for (; end < source.length; end++) {
          final c = source[end];
          if (c == '(') depth++;
          if (c == ')' && --depth == 0) break;
        }
        if (!source.substring(at, end).contains('collapse:')) {
          missing.add(
            '${entity.path}:${'\n'.allMatches(source.substring(0, at)).length + 1}',
          );
        }
        at = source.indexOf('AppFab(', end);
      }
    }
    expect(missing, isEmpty);
  });
}
