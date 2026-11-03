import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/features/expenses/data/datasource/expense_local_datasource_impl.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/pay_later/data/datasource/pay_later_local_datasource_impl.dart';
import 'package:monivo/features/pay_later/data/repository/pay_later_repository_impl.dart';
import 'package:monivo/features/pay_later/domain/entities/pay_later_tab.dart';
import 'package:monivo/features/pay_later/domain/entities/settle_rhythm.dart';
import 'package:monivo/features/pay_later/domain/usecases/reconcile_tab_usecase.dart';

final payLaterStamp = DateTime(2026, 11, 1, 9);

PayLaterTab payLaterTab(
  String id, {
  SettleRhythm rhythm = const OnDemand(),
  String name = 'Cafeteria',
  String currency = 'OMR',
}) => PayLaterTab(
  id: id,
  name: name,
  category: PayLaterTabCategory.foodDining,
  currency: currency,
  rhythm: rhythm,
  createdAt: payLaterStamp,
  updatedAt: payLaterStamp,
);

ExpenseEntity payLaterExpense(String id, {double amount = 5}) => ExpenseEntity(
  id: id,
  budgetId: 'b1',
  amount: amount,
  categoryId: 'cat',
  date: DateTime(2026, 11, 1),
  time: DateTime(2026, 11, 1, 12),
  createdAt: payLaterStamp,
  updatedAt: payLaterStamp,
);

/// Inserts budget `b1` and category `cat`, which [payLaterExpense] uses.
Future<void> seedPayLaterBudget(AppDatabase db) async {
  await db
      .into(db.budgets)
      .insert(
        BudgetsCompanion.insert(
          id: 'b1',
          name: 'b1',
          monthlyAmount: 100,
          remainingAmount: 100,
          currency: 'OMR',
          startDate: DateTime(2026, 11, 1),
          endDate: DateTime(2026, 11, 30),
        ),
      );
  await db
      .into(db.categories)
      .insertOnConflictUpdate(
        CategoriesCompanion.insert(
          id: 'cat',
          name: 'Cat',
          icon: 'i',
          colorHex: '#000000',
        ),
      );
}

Future<void> addPayLaterExpense(AppDatabase db, ExpenseEntity e) =>
    ExpenseLocalDataSourceImpl(database: db).createExpense(e);

/// A real [ReconcileTabUseCase] reading and writing [db], as DI builds it.
ReconcileTabUseCase reconcileTabsOn(AppDatabase db) => ReconcileTabUseCase(
  repository: PayLaterRepositoryImpl(
    localDataSource: PayLaterLocalDataSourceImpl(database: db),
  ),
);
