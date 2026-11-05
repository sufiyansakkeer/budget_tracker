import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'package:monivo/features/dashboard/presentation/widgets/safe_spending_hero.dart';

import 'safe_to_spend_fixtures.dart';

void main() {
  Future<void> pump(WidgetTester tester, SafeToSpendEntity entity) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: GoRouter(
          initialLocation: '/app/home',
          routes: [
            GoRoute(
              path: '/app/home',
              builder: (_, _) => Scaffold(
                body: SafeSpendingNotRunningCard(
                  safeToSpend: entity,
                  onSwitch: () {},
                ),
              ),
            ),
            GoRoute(
              path: '/app/budgets/create',
              builder: (_, state) => Scaffold(
                body: Text('Form ${state.uri.queryParameters['next']}'),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('UX-022 · an ended budget offers "Start next period", which '
      'opens the form prefilled from it', (tester) async {
    await pump(tester, safeToSpend(today: DateTime(2026, 9, 5)));

    expect(find.text('This budget ended 31 Aug'), findsOneWidget);
    await tester.tap(find.text('Start next period'));
    await tester.pumpAndSettle();
    expect(find.text('Form b1'), findsOneWidget);
  });

  testWidgets('a budget that has not started offers a new budget instead', (
    tester,
  ) async {
    await pump(tester, safeToSpend(today: DateTime(2026, 7, 25)));

    expect(find.text('Start next period'), findsNothing);
    expect(find.text('New budget'), findsOneWidget);
  });
}
