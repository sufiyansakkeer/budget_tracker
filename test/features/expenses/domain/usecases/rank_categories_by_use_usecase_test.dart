import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/usecases/rank_categories_by_use_usecase.dart';

void main() {
  const rank = RankCategoriesByUseUseCase();
  ExpenseCategory category(String id, {bool archived = false}) =>
      ExpenseCategory(
        id: id,
        name: id,
        icon: 'category',
        colorHex: '#888888',
        isArchived: archived,
      );
  final catalogue = [for (final id in 'abcdefg'.split('')) category(id)];

  var seq = 0;
  ExpenseEntity spent(String categoryId, {int day = 1, String? billId}) {
    final at = DateTime(2026, 10, day, 12, seq++);
    return ExpenseEntity(
      id: 'e$seq',
      budgetId: 'b',
      amount: 10,
      categoryId: categoryId,
      date: DateTime(2026, 10, day),
      time: at,
      createdAt: at,
      updatedAt: at,
      billId: billId,
    );
  }

  List<String> ids(List<ExpenseCategory> list) => [for (final c in list) c.id];

  test('most used first, then filled from the catalogue', () {
    final result = rank(
      categories: catalogue,
      expenses: [spent('d'), spent('d'), spent('f'), spent('d'), spent('f')],
    );
    expect(ids(result), ['d', 'f', 'a', 'b', 'c']);
  });

  test('a tie goes to the most recently used, then catalogue order', () {
    final result = rank(
      categories: catalogue,
      expenses: [spent('b', day: 2), spent('e', day: 5), spent('c', day: 5)],
    );
    // e and c both on day 5; c was recorded later.
    expect(ids(result).take(3), ['c', 'e', 'b']);
  });

  test('bill payments and unknown categories do not count', () {
    final result = rank(
      categories: catalogue,
      expenses: [
        spent('g', billId: 'rent'),
        spent('g', billId: 'rent'),
        spent('zz'),
        spent('c'),
      ],
    );
    expect(ids(result), ['c', 'a', 'b', 'd', 'e']);
  });

  test('archived categories are never offered', () {
    final result = rank(
      categories: [category('a', archived: true), ...catalogue.skip(1)],
      expenses: [spent('a'), spent('a'), spent('b')],
    );
    expect(ids(result), ['b', 'c', 'd', 'e', 'f']);
  });

  test('respects the limit and an empty catalogue', () {
    expect(rank(categories: catalogue, expenses: const [], limit: 2), [
      catalogue[0],
      catalogue[1],
    ]);
    expect(rank(categories: const [], expenses: [spent('a')]), isEmpty);
  });
}
