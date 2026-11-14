import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/widgets/app_track.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/presentation/widgets/transaction_row.dart';
import 'package:monivo/features/reports/domain/entities/category_analytics.dart';
import 'package:monivo/features/reports/presentation/widgets/category_ranking.dart';

void main() {
  ExpenseEntity spent(String id, String categoryId, int day) {
    final at = DateTime(2026, 10, day, 12);
    return ExpenseEntity(
      id: id,
      budgetId: 'b',
      amount: 10,
      categoryId: categoryId,
      note: 'Note $id',
      date: DateTime(2026, 10, day),
      time: at,
      createdAt: at,
      updatedAt: at,
    );
  }

  const food = CategoryAnalytics(
    categoryId: 'food',
    categoryName: 'Food',
    colorHex: '#FF6B6B',
    totalAmount: 370,
    transactionCount: 2,
    percentageOfTotal: 37,
  );
  const fuel = CategoryAnalytics(
    categoryId: 'fuel',
    categoryName: 'Fuel',
    colorHex: '#FF9F43',
    totalAmount: 100,
    transactionCount: 1,
    percentageOfTotal: 10,
  );

  Future<List<ExpenseEntity>> pump(
    WidgetTester tester,
    List<ExpenseEntity> expenses,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = <ExpenseEntity>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: CategoryRanking(
              analytics: const [food, fuel],
              categories: defaultCategories,
              expenses: expenses,
              currency: 'INR',
              onOpenExpense: opened.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return opened;
  }

  testWidgets('UX-088: bars have no track, so the largest does not read as '
      'a full bar', (tester) async {
    await pump(tester, const []);
    final tracks = tester.widgetList<AppTrack>(find.byType(AppTrack));
    expect(tracks, hasLength(2));
    for (final track in tracks) {
      expect(track.trackColor, Colors.transparent);
    }
  });

  testWidgets('UX-090: an expense in the category list opens', (tester) async {
    final opened = await pump(tester, [
      spent('a', 'food', 3),
      spent('b', 'food', 5),
      spent('c', 'fuel', 4),
    ]);
    await tester.tap(find.byKey(const ValueKey('rank_food')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Note a'));
    await tester.pumpAndSettle();

    expect(opened.map((e) => e.id), ['a']);
    // The sheet closed first: the details may change what it listed.
    expect(find.text('Note b'), findsNothing);
  });

  testWidgets('UX-090: a long category list is built lazily', (tester) async {
    await pump(tester, [
      for (var i = 0; i < 300; i++) spent('e$i', 'food', 1 + i % 28),
    ]);
    await tester.tap(find.byKey(const ValueKey('rank_food')));
    await tester.pumpAndSettle();
    expect(
      find.byType(TransactionRow).evaluate().length,
      lessThan(60),
      reason: 'only the rows on screen',
    );
  });
}
