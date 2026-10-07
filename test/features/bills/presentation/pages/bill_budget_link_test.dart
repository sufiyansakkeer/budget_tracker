import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/bills/presentation/bloc/bill_state.dart';
import 'package:monivo/features/bills/presentation/pages/bill_budget_link.dart';
import 'package:monivo/features/bills/presentation/pages/bill_widgets.dart';

BudgetEntity budget(
  String id, {
  required DateTime start,
  required DateTime end,
  String? name,
  bool archived = false,
  String currency = 'INR',
}) => BudgetEntity(
  id: id,
  name: name ?? id,
  monthlyAmount: 30000,
  remainingAmount: 30000,
  currency: currency,
  startDate: start,
  endDate: end,
  isArchived: archived,
  createdAt: start,
  updatedAt: start,
);

BillEntity bill(
  String id, {
  String? budgetId,
  bool isPaid = false,
  DateTime? due,
}) => BillEntity(
  id: id,
  title: 'Bill $id',
  amount: 1500,
  currency: 'INR',
  category: BillCategory.rent,
  dueDate: due ?? DateTime(2026, 10, 20),
  budgetId: budgetId,
  isPaid: isPaid,
  paidDate: isPaid ? DateTime(2026, 10, 5) : null,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
);

void main() {
  final today = DateTime(2026, 10, 7, 15, 30);
  final september = budget(
    'sep',
    name: 'September 2026',
    start: DateTime(2026, 9, 1),
    end: DateTime(2026, 9, 30),
  );
  final october = budget(
    'oct',
    name: 'October 2026',
    start: DateTime(2026, 10, 1),
    end: DateTime(2026, 10, 31),
  );
  final november = budget(
    'nov',
    name: 'November 2026',
    start: DateTime(2026, 11, 1),
    end: DateTime(2026, 11, 30),
  );
  final archived = budget(
    'arch',
    name: 'Trip',
    start: DateTime(2026, 10, 1),
    end: DateTime(2026, 12, 31),
    archived: true,
  );

  group('BillBudgetLink.budgetLabel', () {
    test('a running or upcoming budget is just its name', () {
      expect(BillBudgetLink.budgetLabel(october, today), 'October 2026');
      expect(BillBudgetLink.budgetLabel(november, today), 'November 2026');
    });

    test('an ended budget is marked ended', () {
      expect(
        BillBudgetLink.budgetLabel(september, today),
        'September 2026 · ended',
      );
    });

    test('a budget ending today is not ended yet', () {
      final endsToday = budget(
        'e',
        name: 'Week',
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 7),
      );
      expect(BillBudgetLink.budgetLabel(endsToday, today), 'Week');
    });

    test('an archived budget is marked archived, even if running', () {
      expect(BillBudgetLink.budgetLabel(archived, today), 'Trip · archived');
    });
  });

  group('BillBudgetLink.pickerOptions', () {
    final all = [november, archived, september, october];

    test('lists budgets that are not archived and not ended, by start', () {
      final options = BillBudgetLink.pickerOptions(all, today: today);
      expect(options.map((b) => b.id), ['oct', 'nov']);
    });

    test('always includes the currently linked ended budget', () {
      final options = BillBudgetLink.pickerOptions(
        all,
        currentId: 'sep',
        today: today,
      );
      expect(options.map((b) => b.id), ['sep', 'oct', 'nov']);
    });

    test('always includes the currently linked archived budget', () {
      final options = BillBudgetLink.pickerOptions(
        all,
        currentId: 'arch',
        today: today,
      );
      expect(options.map((b) => b.id), containsAll(['arch', 'oct', 'nov']));
      expect(options, hasLength(3));
    });

    test('is empty when nothing is running or upcoming', () {
      expect(
        BillBudgetLink.pickerOptions([september, archived], today: today),
        isEmpty,
      );
    });
  });

  group('BillFilter.notLinked', () {
    test('keeps only bills without a budget', () {
      final state = BillState(
        allBills: [
          bill('a', budgetId: 'oct'),
          bill('b'),
          bill('c', isPaid: true),
        ],
        filter: BillFilter.notLinked,
      );
      expect(state.filteredBills.map((b) => b.id), ['b', 'c']);
      expect(BillFilter.notLinked.label, 'Not linked');
    });
  });

  group('BillCard budget line', () {
    Widget wrap(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );

    testWidgets('a linked bill says which budget pays it', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          BillCard(
            bill: bill('a', budgetId: 'oct'),
            showBudgetLink: true,
            budgetName: 'October 2026',
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Paid from October 2026'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r', paid from October 2026$')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('an unlinked bill says it is not linked', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(BillCard(bill: bill('b'), showBudgetLink: true, onTap: () {})),
      );

      expect(find.text('Not linked'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r', not linked to a budget$')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the line is opt-in and hidden when the name is unknown', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(BillCard(bill: bill('b'))));
      expect(find.text('Not linked'), findsNothing);

      await tester.pumpWidget(
        wrap(BillCard(bill: bill('a', budgetId: 'oct'), showBudgetLink: true)),
      );
      expect(find.textContaining('Paid from'), findsNothing);
    });

    testWidgets('meets tap target, labelling and contrast guidelines with '
        'the budget line', (tester) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Column(
                children: [
                  BillCard(
                    bill: bill('a', budgetId: 'oct'),
                    showBudgetLink: true,
                    budgetName: 'October 2026',
                    onTap: () {},
                    onMarkPaid: () {},
                  ),
                  BillCard(bill: bill('b'), showBudgetLink: true, onTap: () {}),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      }
    });

    testWidgets('the quick action uses the given label', (tester) async {
      await tester.pumpWidget(
        wrap(
          BillCard(
            bill: bill('a', budgetId: 'oct'),
            onMarkPaid: () {},
            markPaidLabel: 'Mark paid & record expense',
          ),
        ),
      );
      expect(find.byTooltip('Mark paid & record expense'), findsOneWidget);
    });
  });
}
