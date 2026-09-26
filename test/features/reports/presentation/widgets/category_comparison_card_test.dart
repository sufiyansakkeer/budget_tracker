import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/reports/domain/entities/category_comparison.dart';
import 'package:monivo/features/reports/domain/entities/report_period.dart';
import 'package:monivo/features/reports/presentation/widgets/category_comparison_card.dart';

void main() {
  final range = ReportRange(
    start: DateTime(2026, 9, 8),
    end: DateTime(2026, 9, 14),
    period: ReportPeriod.custom,
  );

  Widget harness(List<CategoryComparison> comparison) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: SingleChildScrollView(
        child: CategoryComparisonCard(
          comparison: comparison,
          categories: defaultCategories,
          range: range,
          currency: 'INR',
        ),
      ),
    ),
  );

  const up = CategoryComparison(
    categoryId: 'food',
    categoryName: 'Food',
    colorHex: '#FF6B6B',
    currentAmount: 600,
    previousAmount: 500,
  );
  const down = CategoryComparison(
    categoryId: 'fuel',
    categoryName: 'Fuel',
    colorHex: '#FF9F43',
    currentAmount: 100,
    previousAmount: 400,
  );
  const fresh = CategoryComparison(
    categoryId: 'travel',
    categoryName: 'Travel',
    colorHex: '#54A0FF',
    currentAmount: 200,
    previousAmount: 0,
  );

  testWidgets('hasComparison is false without a previous period', (
    tester,
  ) async {
    expect(CategoryComparisonCard.hasComparison(const [fresh]), isFalse);
    expect(CategoryComparisonCard.hasComparison(const [up]), isTrue);
  });

  testWidgets('shows the compared window in the caption', (tester) async {
    await tester.pumpWidget(harness(const [up]));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 Sep – 7 Sep'), findsOneWidget);
    expect(find.textContaining('7 days'), findsOneWidget);
  });

  testWidgets('labels increases, decreases and new categories', (tester) async {
    await tester.pumpWidget(harness(const [up, down, fresh]));
    await tester.pumpAndSettle();

    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Fuel'), findsOneWidget);
    expect(find.text('Travel'), findsOneWidget);

    expect(find.textContaining('20%'), findsOneWidget, reason: 'food +20%');
    expect(find.textContaining('75%'), findsOneWidget, reason: 'fuel −75%');
    expect(find.text('New'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
  });

  testWidgets('lists at most five categories', (tester) async {
    final many = [
      for (var i = 0; i < 8; i++)
        CategoryComparison(
          categoryId: 'c$i',
          categoryName: 'Cat $i',
          colorHex: '#FF6B6B',
          currentAmount: (8 - i) * 100,
          previousAmount: 10,
        ),
    ];
    await tester.pumpWidget(harness(many));
    await tester.pumpAndSettle();

    expect(find.text('Cat 0'), findsOneWidget);
    expect(find.text('Cat 4'), findsOneWidget);
    expect(find.text('Cat 5'), findsNothing);
  });

  testWidgets('each row exposes a readable semantics label', (tester) async {
    await tester.pumpWidget(harness(const [down]));
    await tester.pumpAndSettle();
    final node = tester.getSemantics(
      find.byKey(const ValueKey('comparison_fuel')),
    );
    expect(node.label, contains('Fuel'));
    expect(node.label, contains('down'));
  });
}
