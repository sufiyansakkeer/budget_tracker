import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/expenses/presentation/history/widgets/activity_switch.dart';

void main() {
  Future<GoRouter> pump(WidgetTester tester, String at) async {
    final router = GoRouter(
      initialLocation: at,
      routes: [
        GoRoute(
          path: '/app/expenses',
          builder: (_, _) => const Scaffold(
            body: Column(
              children: [Text('stream'), ActivitySwitch(insights: false)],
            ),
          ),
        ),
        GoRoute(
          path: '/app/reports',
          builder: (_, _) => const Scaffold(
            body: Column(
              children: [Text('insights'), ActivitySwitch(insights: true)],
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('Stream and Insights, one switch apart (blueprint)', (
    tester,
  ) async {
    await pump(tester, '/app/expenses');
    final segments = tester.widget<SegmentedButton<bool>>(
      find.byType(SegmentedButton<bool>),
    );
    expect(segments.selected, {false});
    expect(find.text('Stream'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
    expect(find.text('insights'), findsOneWidget);

    await tester.tap(find.text('Stream'));
    await tester.pumpAndSettle();
    expect(find.text('stream'), findsOneWidget);
  });
}
