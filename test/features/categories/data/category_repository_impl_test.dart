import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/core/database/default_categories.dart';
import 'package:monivo/features/categories/data/datasource/category_local_datasource_impl.dart';
import 'package:monivo/features/categories/data/repository/category_repository_impl.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';

import '../../../helpers/in_memory_database.dart';

void main() {
  late AppDatabase db;
  late CategoryRepositoryImpl repo;

  setUp(() async {
    db = await createInMemoryDatabase();
    repo = CategoryRepositoryImpl(
      localDataSource: CategoryLocalDataSourceImpl(database: db),
    );
  });

  tearDown(() => db.close());

  test('returns the seeded defaults with archived=false', () async {
    final all = await repo.getCategories();
    expect(all.length, defaultCategoryRows.length);
    expect(all.every((c) => c.isSystem && !c.isArchived), isTrue);
  });

  test('create, update, archive and delete round-trip', () async {
    const gym = ExpenseCategory(
      id: 'gym',
      name: 'Gym',
      icon: 'fitness_center',
      colorHex: '#10AC84',
      isSystem: false,
    );
    await repo.createCategory(gym);
    expect(await repo.getCategoryById('gym'), gym);

    await repo.updateCategory(
      gym.copyWith(name: 'Fitness', colorHex: '#EE5253', isArchived: true),
    );
    final updated = (await repo.getCategoryById('gym'))!;
    expect(updated.name, 'Fitness');
    expect(updated.colorHex, '#EE5253');
    expect(updated.isArchived, isTrue);
    expect(updated.isSystem, isFalse, reason: 'flag is never touched');

    await repo.deleteCategory('gym');
    expect(await repo.getCategoryById('gym'), isNull);
  });

  test('counts expenses referencing a category', () async {
    await db
        .into(db.budgets)
        .insert(
          BudgetsCompanion.insert(
            id: 'b1',
            name: 'B',
            monthlyAmount: 100,
            remainingAmount: 100,
            currency: 'INR',
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 30),
          ),
        );
    for (var i = 0; i < 2; i++) {
      await db
          .into(db.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: 'e$i',
              budgetId: 'b1',
              amount: 5,
              categoryId: 'food',
              date: DateTime(2026, 9, 2),
              note: const Value('x'),
            ),
          );
    }
    expect(await repo.countExpenses('food'), 2);
    expect(await repo.countExpenses('travel'), 0);
  });

  test('the database refuses to delete a category that is in use', () async {
    await db
        .into(db.budgets)
        .insert(
          BudgetsCompanion.insert(
            id: 'b1',
            name: 'B',
            monthlyAmount: 100,
            remainingAmount: 100,
            currency: 'INR',
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 30),
          ),
        );
    await db
        .into(db.expenses)
        .insert(
          ExpensesCompanion.insert(
            id: 'e1',
            budgetId: 'b1',
            amount: 5,
            categoryId: 'food',
            date: DateTime(2026, 9, 2),
          ),
        );
    await expectLater(repo.deleteCategory('food'), throwsA(anything));
    expect(await repo.getCategoryById('food'), isNotNull);
  });
}
