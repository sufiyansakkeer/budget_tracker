import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/entities/budget_status.dart';
import 'package:monivo/features/dashboard/domain/entities/budget_daily_limit_entity.dart';
import 'package:monivo/features/dashboard/domain/entities/spending_target_status.dart';
import 'package:monivo/features/dashboard/presentation/widgets/safe_spending_hero.dart';

BudgetDailyLimitEntity limit({
  double dailyLimit = 1000,
  double spentToday = 250,
  double weeklyTarget = 7000,
  double weeklySpent = 3000,
  SpendingTargetStatus status = SpendingTargetStatus.onTrack,
}) {
  final over = spentToday > dailyLimit;
  return BudgetDailyLimitEntity(
    budgetId: 'b1',
    budgetName: 'Personal',
    dailyLimit: dailyLimit,
    spentToday: spentToday,
    remainingToday: over ? 0 : dailyLimit - spentToday,
    exceededToday: over ? spentToday - dailyLimit : 0,
    progress: dailyLimit == 0 ? 0 : (spentToday / dailyLimit).clamp(0.0, 1.0),
    isOverLimit: over,
    status: status,
    budgetStatus: BudgetStatus.underBudget,
    budgetUtilization: 0.3,
    monthlyAmount: 30000,
    totalSpent: 9000,
    remainingBudget: 21000,
    remainingDays: 21,
    weeklyTarget: weeklyTarget,
    weeklySpent: weeklySpent,
    weeklyRemaining: (weeklyTarget - weeklySpent).clamp(0, double.infinity),
    weeklyExceeded: weeklySpent > weeklyTarget ? weeklySpent - weeklyTarget : 0,
    weeklyProgress: weeklyTarget == 0
        ? 0
        : (weeklySpent / weeklyTarget).clamp(0.0, 1.0),
    weeklyStatus: SpendingTargetStatus.onTrack,
    currency: 'INR',
    startDate: DateTime(2026, 9, 1),
    endDate: DateTime(2026, 9, 30),
  );
}

void main() {
  Widget harness(BudgetDailyLimitEntity value) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: SingleChildScrollView(child: SafeSpendingHero(limit: value)),
    ),
  );

  testWidgets('shows the daily limit, spent and left figures', (tester) async {
    await tester.pumpWidget(harness(limit()));
    await tester.pumpAndSettle();

    expect(find.text("Today's Safe Spending"), findsOneWidget);
    expect(find.text('Spent today'), findsOneWidget);
    expect(find.text('Left today'), findsOneWidget);
    expect(find.text('₹1,000'), findsOneWidget);
    expect(find.text('₹250'), findsOneWidget);
    expect(find.text('₹750'), findsOneWidget);
  });

  testWidgets('switches to "Over by" when the limit is exceeded', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(limit(spentToday: 1400, status: SpendingTargetStatus.exceeded)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Over by'), findsOneWidget);
    expect(find.text('Left today'), findsNothing);
  });

  testWidgets('adds a weekly line when there is a weekly share', (
    tester,
  ) async {
    await tester.pumpWidget(harness(limit()));
    await tester.pumpAndSettle();

    expect(find.text('This week'), findsOneWidget);
    expect(find.text('₹3,000 of ₹7,000'), findsOneWidget);
  });

  testWidgets('omits the weekly line when there is no weekly share', (
    tester,
  ) async {
    await tester.pumpWidget(harness(limit(weeklyTarget: 0, weeklySpent: 0)));
    await tester.pumpAndSettle();

    expect(find.text('This week'), findsNothing);
  });
}
