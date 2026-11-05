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

  Future<void> pump(
    WidgetTester tester,
    List<BillEntity> bills, {
    Set<String> setAside = const {'a'},
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: UpcomingBillsSection(
              bills: bills,
              activeBudgetId: 'personal',
              setAsideBillIds: setAside,
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

  testWidgets('bills that could not be read say so and offer a retry', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: UpcomingBillsSection(
            bills: const [],
            unavailable: true,
            onRetry: () => retries++,
          ),
        ),
      ),
    );

    expect(find.text("Couldn't load your bills."), findsOneWidget);
    expect(find.textContaining('No bills due soon'), findsNothing);
    expect(find.text('Add bill'), findsNothing);

    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  testWidgets('a bill of the budget on screen that it does not set aside '
      'does not read "Set aside"', (tester) async {
    // Due after the budget ends, or in another currency: the budget's
    // safe amount does not count it, so neither does the row.
    await pump(tester, [bill('a', budgetId: 'personal')], setAside: const {});

    expect(find.textContaining('Set aside', findRichText: true), findsNothing);
    expect(
      find.textContaining('Paid from Personal', findRichText: true),
      findsOne,
    );
  });

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

  testWidgets('UX-037: with bills but none coming up it offers "See all"', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: UpcomingBillsSection(bills: [], hasBills: true)),
      ),
    );

    expect(find.widgetWithText(TextButton, 'See all'), findsOneWidget);
    expect(find.text('Add bill'), findsNothing);
  });
}
