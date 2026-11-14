import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/constants/app_spacing.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_money.dart';
import 'package:monivo/features/dashboard/domain/entities/recent_expense_entity.dart';
import 'package:monivo/features/dashboard/presentation/widgets/recent_expense_tile.dart';
import 'package:monivo/features/expenses/presentation/widgets/transaction_row.dart';

void main() {
  final date = DateTime(2026, 9, 10, 13);
  RecentExpenseEntity expense({String? note}) => RecentExpenseEntity(
    id: 'e1',
    amount: 250,
    categoryId: 'food',
    categoryName: 'Food',
    categoryIcon: 'restaurant',
    categoryColorHex: '#FF6B6B',
    note: note,
    date: date,
    createdAt: date,
  );

  Widget wrap(Widget child, {double textScale = 1}) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: child),
      ),
    ),
  );

  group('Home › Recent without a note (UX-075)', () {
    testWidgets('names the category once, on screen and when spoken', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          RecentExpenseTile(
            expense: expense(),
            currency: 'INR',
            today: date,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Food'), findsOneWidget);
      final label = tester
          .getSemantics(find.byType(TransactionRow))
          .getSemanticsData()
          .label;
      expect(RegExp('Food').allMatches(label), hasLength(1));
      expect(label, contains(AppMoney.format(250, currency: 'INR')));
      handle.dispose();
    });

    testWidgets('with a note the category is the second line', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          RecentExpenseTile(
            expense: expense(note: 'Pizza'),
            currency: 'INR',
            today: date,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Pizza'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      final label = tester
          .getSemantics(find.byType(TransactionRow))
          .getSemanticsData()
          .label;
      expect(label, startsWith('Pizza, Food, '));
      handle.dispose();
    });
  });

  group('TransactionRow receipt mark (UX-108)', () {
    Widget row({double textScale = 1}) => wrap(
      TransactionRow(
        icon: Icons.restaurant,
        color: Colors.red,
        title: 'Pizza',
        detail: 'Food',
        when: 'Today',
        amount: 250,
        currency: 'INR',
        hasReceipt: true,
        semanticLabel: 'Pizza',
      ),
      textScale: textScale,
    );

    testWidgets('grows with large text, up to a normal icon', (tester) async {
      await tester.pumpWidget(row(textScale: 2));
      expect(
        tester.getSize(find.byIcon(Icons.receipt_long_rounded)).width,
        AppSizes.iconLg,
      );
    });

    testWidgets('keeps its size at normal text', (tester) async {
      await tester.pumpWidget(row());
      expect(
        tester.getSize(find.byIcon(Icons.receipt_long_rounded)).width,
        AppSizes.iconXs,
      );
    });
  });
}
