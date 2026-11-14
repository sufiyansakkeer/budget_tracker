import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/commitment_occurrence.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_input.dart';
import 'package:monivo/features/budget/presentation/widgets/change_target_sheet.dart';

// The blueprint's story: ₹60,000 for 1–31 Oct, seen on 8 Oct; ₹1,850 of
// bills and a ₹3,000 savings goal set aside; tomorrow's target ₹880.56.
final _input = SafeToSpendInput(
  budgetId: 'household',
  budgetName: 'October Household',
  currency: 'INR',
  startDate: DateTime(2026, 10, 1),
  endDate: DateTime(2026, 10, 31),
  today: DateTime(2026, 10, 8),
  budgetAmount: 60000,
  periodSpent: 34897,
  todaySpent: 570,
  commitments: [
    CommitmentOccurrence(
      billId: 'rent',
      title: 'Electricity',
      amount: 1850,
      dueDate: DateTime(2026, 10, 12),
      isOverdue: false,
    ),
  ],
  savingsTarget: 3000,
);

void main() {
  late List<(double?, double?)> applied;
  late int forms;

  Future<void> pump(WidgetTester tester) async {
    applied = [];
    forms = 0;
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ChangeTargetSheet(
            input: _input,
            onApply: (reserved, savings) async =>
                applied.add((reserved, savings)),
            onOpenForm: () => forms++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('starts from what is set, with nothing changed', (tester) async {
    await pump(tester);

    expect(find.text('Change your daily target'), findsOneWidget);
    expect(
      find.text(
        'Each change shows its effect a day. Nothing is saved until you '
        'apply it.',
      ),
      findsOneWidget,
    );
    expect(find.text('Target from tomorrow'), findsOneWidget);
    expect(find.text('₹880.56'), findsWidgets);
  });

  testWidgets(
    'a smaller savings goal raises the target, and says by how much',
    (tester) async {
      await pump(tester);
      await tester.enterText(field('Savings goal'), '2000');
      await tester.pump();

      // ₹1,000 more over the 23 days after today.
      expect(find.text('+₹43.48 a day'), findsOneWidget);
      expect(find.text('₹880.56 → ₹924.04'), findsOneWidget);
    },
  );

  testWidgets('Apply saves the set-asides; nothing before', (tester) async {
    await pump(tester);
    await tester.enterText(field('Savings goal'), '2000');
    await tester.enterText(field('Kept aside'), '500');
    await tester.pump();
    expect(applied, isEmpty);

    await tester.tap(find.text('Apply'));
    await tester.pump();
    expect(applied, [(500.0, 2000.0)]);
  });

  testWidgets('end date and amount open the budget form', (tester) async {
    await pump(tester);
    await tester.tap(find.text('End date'));
    await tester.tap(find.text('Budget amount'));
    expect(forms, 2);
  });
}
