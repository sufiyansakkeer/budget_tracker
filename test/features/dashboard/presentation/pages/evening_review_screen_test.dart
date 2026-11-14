import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/dashboard/domain/entities/recent_expense_entity.dart';
import 'package:monivo/features/dashboard/presentation/pages/evening_review_screen.dart';
import 'package:monivo/features/dashboard/presentation/widgets/target_ring.dart';

import '../widgets/safe_to_spend_fixtures.dart';

void main() {
  RecentExpenseEntity dinner(double amount) => RecentExpenseEntity(
    id: 'dinner',
    amount: amount,
    categoryId: 'food',
    categoryName: 'Food',
    categoryIcon: 'restaurant',
    categoryColorHex: '#FF7043',
    note: 'Dinner',
    date: fixtureToday,
    createdAt: DateTime(2026, 8, 10, 19, 50),
  );

  late int quickAdds;

  Future<void> pump(WidgetTester tester, EveningReview? review) async {
    quickAdds = 0;
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: EveningReviewScreen(
          load: () async => review,
          onAddForgotten: (_) async => quickAdds++,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Fixture: 1,000 a day, 22 days left.
  testWidgets('the day\'s ring, tomorrow\'s target and how much it moved', (
    tester,
  ) async {
    await pump(tester, (
      safeToSpend(periodSpent: 570, todaySpent: 570),
      [dinner(570)],
    ));

    expect(find.text('Today, reviewed'), findsOneWidget);
    expect(find.byType(TargetRing), findsOneWidget);
    expect(find.text('Left'), findsOneWidget);
    expect(find.text("Tomorrow's target"), findsOneWidget);
    // 21,430 ÷ 21 = 1,020.47…: up ₹20.47 from today's 1,000.
    expect(find.text('₹1,020.47'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    expect(find.text('+₹20.47'), findsOneWidget);
  });

  testWidgets('a day over: the ring says how far, tomorrow moves down', (
    tester,
  ) async {
    await pump(tester, (
      safeToSpend(periodSpent: 1400, todaySpent: 1400),
      [dinner(1400)],
    ));
    expect(find.text('Over'), findsOneWidget);
    // 20,600 ÷ 21 = 980.95…: down ₹19.05.
    expect(find.text('−₹19.05'), findsOneWidget);
  });

  testWidgets('"Anything you forgot?" comes before the list and adds one', (
    tester,
  ) async {
    await pump(tester, (
      safeToSpend(periodSpent: 570, todaySpent: 570),
      [dinner(570)],
    ));
    expect(
      tester.getTopLeft(find.text('Anything you forgot?')).dy,
      lessThan(tester.getTopLeft(find.text('Dinner')).dy),
    );
    await tester.tap(find.text('Add an expense from today'));
    expect(quickAdds, 1);
    expect(find.text('Done for today'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('no running budget: says so', (tester) async {
    await pump(tester, null);
    expect(find.text('No budget is running today'), findsOneWidget);
    expect(find.byType(TargetRing), findsNothing);
  });
}
