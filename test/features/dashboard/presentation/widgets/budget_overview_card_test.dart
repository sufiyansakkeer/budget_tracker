import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/entities/budget_calculation_input.dart';
import 'package:monivo/features/budget/domain/entities/budget_summary_entity.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/dashboard/presentation/widgets/budget_overview_card.dart';

/// "Day X of N" comes from the calculation service's calendar-day counts
/// (review: the card re-counted the period with a local
/// `difference().inDays`, one day short when the stored start carried a
/// time of day or a daylight-saving change fell inside the period).
void main() {
  BudgetSummaryEntity summary({
    required DateTime start,
    required DateTime end,
    required DateTime today,
  }) => BudgetCalculationService().buildSummary(
    BudgetCalculationInput(
      monthlyAmount: 31000,
      totalSpent: 0,
      todaySpending: 0,
      referenceDate: today,
      startDate: start,
      endDate: end,
    ),
    currency: 'INR',
  );

  Future<void> pump(WidgetTester tester, BudgetSummaryEntity s) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: BudgetOverviewCard(summary: s)),
        ),
      );

  test('totalDays equals the service\'s period length', () {
    final s = summary(
      start: DateTime(2026, 8, 1, 14, 30),
      end: DateTime(2026, 8, 31),
      today: DateTime(2026, 8, 10),
    );
    expect(
      s.totalDays,
      BudgetCalculationService().daysInPeriod(
        startDate: DateTime(2026, 8, 1, 14, 30),
        endDate: DateTime(2026, 8, 31),
      ),
    );
    expect(s.totalDays, 31);
  });

  testWidgets('a start stored with a time of day still counts its first day', (
    tester,
  ) async {
    // Onboarding stored the moment it ran; the end was picked as a date.
    // The old count: (31 Aug 00:00 − 1 Aug 14:30).inDays + 1 = 30.
    await pump(
      tester,
      summary(
        start: DateTime(2026, 8, 1, 14, 30),
        end: DateTime(2026, 8, 31),
        today: DateTime(2026, 8, 1, 18),
      ),
    );

    expect(find.text('Day 1 of 31 · 31 days left'), findsOneWidget);
  });

  testWidgets('a period with a daylight-saving change keeps every day', (
    tester,
  ) async {
    // 8 Mar 2026 is 23 hours long in US zones (run with
    // TZ=America/New_York to exercise it); the period is still 31 days.
    await pump(
      tester,
      summary(
        start: DateTime(2026, 3, 1),
        end: DateTime(2026, 3, 31),
        today: DateTime(2026, 3, 31),
      ),
    );

    expect(find.text('Day 31 of 31 · 1 day left'), findsOneWidget);
  });
}
