import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/expenses/presentation/add/add_sheet.dart';

void main() {
  late int quickAdds;

  setUp(() {
    quickAdds = 0;
    AddSheet.openQuickAdd = (_) async => quickAdds++;
  });
  tearDown(AddSheet.resetQuickAdd);

  Future<void> open(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/app/home',
      routes: [
        GoRoute(
          path: '/app/home',
          builder: (_, _) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => AddSheet.show(context),
                child: const Text('+'),
              ),
            ),
          ),
        ),
        for (final path in [
          '/app/expenses/add',
          '/app/bills/add',
          '/app/pay-later',
        ])
          GoRoute(
            path: path,
            builder: (_, _) => Scaffold(body: Text('page $path')),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.tap(find.text('+'));
    await tester.pumpAndSettle();
  }

  testWidgets('offers every way money moves, expense first (blueprint)', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Add'), findsOneWidget);
    for (final (title, line) in const [
      ('Expense', 'Spent money now'),
      ('Bill', 'Something due later'),
      ('On a tab', 'Bought now, pay later'),
      ('Tab payment', 'Paid off some of a tab'),
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
      expect(find.text(line), findsOneWidget, reason: line);
    }
    // A 2 × 2 grid: Expense and Bill side by side, the tabs below them.
    double x(String t) => tester.getTopLeft(find.text(t)).dx;
    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(y('Bill'), y('Expense'));
    expect(x('Bill'), greaterThan(x('Expense')));
    expect(y('On a tab'), greaterThan(y('Expense')));
    // The expense tile is the filled one.
    final scheme = AppTheme.lightTheme.colorScheme;
    Color? fill(String key) =>
        tester.widget<Material>(find.byKey(Key(key))).color;
    expect(fill('addSheet_expense'), scheme.primaryContainer);
    expect(fill('addSheet_bill'), scheme.surfaceContainer);
  });

  testWidgets('Expense closes the sheet and opens quick add', (tester) async {
    await open(tester);
    await tester.tap(find.text('Expense'));
    await tester.pumpAndSettle();

    expect(quickAdds, 1);
    expect(find.text('Bill'), findsNothing);
  });

  for (final (choice, path) in const [
    ('Bill', '/app/bills/add'),
    ('On a tab', '/app/expenses/add'),
    ('Tab payment', '/app/pay-later'),
  ]) {
    testWidgets('$choice opens $path', (tester) async {
      await open(tester);
      await tester.tap(find.text(choice));
      await tester.pumpAndSettle();

      expect(find.text('page $path'), findsOneWidget);
      expect(quickAdds, 0);
    });
  }
}
