import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/dashboard/presentation/widgets/upcoming_bills_section.dart';

void main() {
  final today = DateTime.now();
  BillEntity bill(String id, {String? budgetId}) => BillEntity(
    id: id,
    title: 'Bill $id',
    amount: 500,
    currency: 'INR',
    category: BillCategory.electricity,
    dueDate: DateTime(today.year, today.month, today.day + 4),
    createdAt: DateTime(2026, 10, 1),
    updatedAt: DateTime(2026, 10, 1),
    budgetId: budgetId,
  );

  Future<void> pump(WidgetTester tester, List<BillEntity> bills) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: UpcomingBillsSection(
              bills: bills,
              activeBudgetId: 'personal',
              budgetNames: const {
                'personal': 'Personal',
                'household': 'Household',
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('only a bill the budget on screen pays reads "Set aside"', (
    tester,
  ) async {
    // Review: Home said "Set aside" for bills another budget pays, under a
    // "nothing is set aside from this budget" line.
    await pump(tester, [
      bill('a', budgetId: 'personal'),
      bill('b', budgetId: 'household'),
      bill('c', budgetId: 'archived'),
      bill('d'),
    ]);

    expect(find.text('Set aside', findRichText: true), findsNothing);
    expect(find.textContaining('Set aside', findRichText: true), findsOne);
    expect(
      find.textContaining('Paid from Household', findRichText: true),
      findsOne,
    );
    expect(
      find.textContaining('Paid from another budget', findRichText: true),
      findsOne,
    );
    expect(find.textContaining('Not linked', findRichText: true), findsOne);
  });

  testWidgets('UX-006: an overdue bill says so in words, and the section '
      'counts how many are overdue', (tester) async {
    final overdue = bill(
      'late',
      budgetId: 'personal',
    ).copyWith(dueDate: DateTime(today.year, today.month, today.day - 2));
    await pump(tester, [overdue, bill('soon', budgetId: 'personal')]);

    expect(find.text('1 bill is overdue'), findsOneWidget);
    expect(
      find.textContaining('2 days overdue', findRichText: true),
      findsOneWidget,
    );
    // An overdue bill alone still lists, rather than "No bills due soon".
    await pump(tester, [overdue]);
    expect(find.textContaining('No bills due soon'), findsNothing);
    expect(find.text('See all'), findsOneWidget);
  });

  testWidgets('no overdue bill, no overdue line', (tester) async {
    await pump(tester, [bill('soon')]);
    expect(find.textContaining('overdue'), findsNothing);
  });

  testWidgets('reads the paying budget aloud', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, [bill('b', budgetId: 'household')]);

    expect(
      find.bySemanticsLabel(RegExp(r'^Bill b, .*, paid from household, ₹500')),
      findsOneWidget,
    );
    handle.dispose();
  });
}
