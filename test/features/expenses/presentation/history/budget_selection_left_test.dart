import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_money.dart';
import 'package:monivo/features/expenses/presentation/history/widgets/budget_selection_sheet.dart';

/// UX-087: the budget picker rounded "left" to whole units, so ₹0.60 read
/// as "₹1 left", more than can be spent.
void main() {
  testWidgets('"left" is floored, the total exact', (tester) async {
    final budget = BudgetEntity(
      id: 'b',
      name: 'Household',
      monthlyAmount: 1000.5,
      remainingAmount: 0.6,
      currency: 'INR',
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 31),
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: BudgetSelectionSheet(
            allBudgets: [budget],
            initiallySelected: const ['b'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final left = AppMoney.format(0.6, currency: 'INR', floored: true);
    final total = AppMoney.format(1000.5, currency: 'INR');
    expect(find.textContaining('$left left of $total'), findsOneWidget);
    expect(find.textContaining('₹1 left'), findsNothing);
  });
}
