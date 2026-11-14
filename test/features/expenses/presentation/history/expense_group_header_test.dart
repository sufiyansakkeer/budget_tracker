import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/day_target.dart';
import 'package:monivo/features/dashboard/presentation/widgets/target_ring.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/entities/expense_group.dart';
import 'package:monivo/features/expenses/presentation/history/widgets/expense_group_header.dart';

void main() {
  final day = DateTime(2026, 10, 7);
  final group = ExpenseGroup(
    type: ExpenseGroupType.earlier,
    date: day,
    expenses: [
      ExpenseEntity(
        id: 'gift',
        budgetId: 'b',
        amount: 4577,
        categoryId: 'shopping',
        date: day,
        time: day,
        createdAt: day,
        updatedAt: day,
      ),
    ],
  );

  Future<void> pump(WidgetTester tester, {DayTarget? target}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ExpenseGroupHeader(
              group: group,
              currency: 'INR',
              dayTarget: target,
            ),
          ),
        ),
      );

  testWidgets('without a target: the day\'s total, as before', (tester) async {
    await pump(tester);
    expect(find.text('Spent ₹4,577'), findsOneWidget);
    expect(find.byType(MiniTargetRing), findsNothing);
  });

  testWidgets('over the day\'s target: a ring and how far over', (
    tester,
  ) async {
    await pump(
      tester,
      target: DayTarget(date: day, target: 1016, spent: 4577, result: -3561),
    );
    expect(find.byType(MiniTargetRing), findsOneWidget);
    expect(find.text('+₹3,561 over'), findsOneWidget);
    // The blueprint's 24dp ring.
    expect(tester.getSize(find.byType(MiniTargetRing)).width, 24);
    expect(find.text('Spent ₹4,577'), findsNothing);
  });

  testWidgets('under it: what was left', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      target: DayTarget(date: day, target: 867.62, spent: 570, result: 297.62),
    );
    expect(find.text('₹297.62 left'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'₹297\.62 left of ₹867\.62')),
      findsOneWidget,
    );
    handle.dispose();
  });
}
