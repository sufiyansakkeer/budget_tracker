import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/currency/currency_formatter.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/entities/budget_list_summary_entity.dart';
import 'package:monivo/features/budget/presentation/widgets/budget_list_summary_card.dart';

/// "Total remaining" never adds different currencies (review: OMR 100 and
/// ₹10,000 showed as "OMR 10,100").
void main() {
  Future<void> pump(
    WidgetTester tester,
    BudgetListSummaryEntity summary,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: BudgetListSummaryCard(summary: summary)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('one currency: one total', (tester) async {
    await pump(
      tester,
      const BudgetListSummaryEntity(
        remainingByCurrency: {'INR': 18500},
        activeBudgetCount: 3,
      ),
    );

    expect(
      find.text(CurrencyFormatter.format(18500, code: 'INR')),
      findsOneWidget,
    );
    expect(find.text('Across 3 budgets running today'), findsOneWidget);
  });

  testWidgets('two currencies: one total each, never combined', (tester) async {
    await pump(
      tester,
      const BudgetListSummaryEntity(
        remainingByCurrency: {'OMR': 100, 'INR': 10000},
        activeBudgetCount: 2,
      ),
    );

    expect(
      find.text(CurrencyFormatter.format(100, code: 'OMR')),
      findsOneWidget,
    );
    expect(
      find.text(CurrencyFormatter.format(10000, code: 'INR')),
      findsOneWidget,
    );
    expect(
      find.text(CurrencyFormatter.format(10100, code: 'OMR')),
      findsNothing,
    );
  });
}
