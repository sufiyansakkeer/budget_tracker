import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/constants/preference_keys.dart';
import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/data/datasource/budget_local_datasource_impl.dart';
import 'package:monivo/features/budget/data/repository/budget_repository_impl.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/settings/domain/entities/settings_failure.dart';
import 'package:monivo/features/settings/domain/usecases/reset_budget_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/in_memory_database.dart';

void main() {
  late AppDatabase database;
  late SharedPreferences prefs;
  late BudgetRepositoryImpl repository;
  late ResetBudgetUseCase useCase;

  BudgetEntity budget({
    String id = 'b1',
    double amount = 30000,
    String currency = 'USD',
    DateTime? start,
  }) {
    final s = start ?? DateTime(2026, 9, 1);
    return BudgetEntity(
      id: id,
      name: 'Trip',
      monthlyAmount: amount,
      remainingAmount: amount,
      currency: currency,
      startDate: s,
      endDate: s.add(const Duration(days: 29)),
      color: '#123456',
      icon: 'flight',
      createdAt: s,
      updatedAt: s,
    );
  }

  setUp(() async {
    database = await createInMemoryDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = BudgetRepositoryImpl(
      localDataSource: BudgetLocalDataSourceImpl(
        database: database,
        sharedPreferences: prefs,
      ),
      calculationService: BudgetCalculationService(),
    );
    useCase = ResetBudgetUseCase(repository: repository);
  });

  tearDown(() => database.close());

  group('resetBudgetAmount', () {
    test('rejects non-positive amounts', () async {
      final result = await useCase.resetBudgetAmount(0);
      expect(result, isA<SettingsError>());
      expect(
        (result as SettingsError).failure.type,
        SettingsErrorType.invalidData,
      );
    });

    test('creates and activates a default budget when none exists', () async {
      final result = await useCase.resetBudgetAmount(5000);
      expect(result, isA<SettingsSuccess<String>>());
      final id = (result as SettingsSuccess<String>).data;

      expect(prefs.getString(PreferenceKeys.activeBudgetId), id);
      final created = await repository.getBudgetById(id);
      expect(created, isNotNull);
      expect(created!.monthlyAmount, 5000);
      expect(created.remainingAmount, 5000);
      expect(created.totalDays, 31);
    });

    test('updates the active budget and recomputes remaining', () async {
      await repository.createBudget(budget());
      await repository.setActiveBudgetId('b1');
      // Spend 800 against it.
      await database
          .into(database.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: 'e1',
              budgetId: 'b1',
              amount: 800,
              categoryId: 'food',
              date: DateTime(2026, 9, 5),
              createdAt: Value(DateTime(2026, 9, 5)),
              updatedAt: Value(DateTime(2026, 9, 5)),
            ),
          );

      final result = await useCase.resetBudgetAmount(20000);
      expect((result as SettingsSuccess<String>).data, 'b1');

      final updated = await repository.getBudgetById('b1');
      expect(updated!.monthlyAmount, 20000);
      expect(updated.remainingAmount, 19200);
      expect(updated.currency, 'USD', reason: 'other fields are preserved');
    });

    test(
      'falls back to the latest budget when the active id is stale',
      () async {
        await repository.createBudget(
          budget(id: 'old', start: DateTime(2026, 1, 1)),
        );
        await repository.createBudget(
          budget(id: 'new', start: DateTime(2026, 9, 1)),
        );
        await prefs.setString(PreferenceKeys.activeBudgetId, 'missing');

        final result = await useCase.resetBudgetAmount(100);
        expect((result as SettingsSuccess<String>).data, 'new');
      },
    );
  });

  group('resetCurrentMonth', () {
    test('archives the active budget and starts one new period', () async {
      await repository.createBudget(budget());
      await repository.setActiveBudgetId('b1');

      final result = await useCase.resetCurrentMonth();
      final newId = (result as SettingsSuccess<String>).data;
      expect(newId, isNot('b1'));

      final all = await repository.getAllBudgets();
      expect(all.length, 2, reason: 'exactly one budget is created');

      final old = all.firstWhere((b) => b.id == 'b1');
      expect(old.isArchived, isTrue);

      final fresh = all.firstWhere((b) => b.id == newId);
      expect(fresh.isArchived, isFalse);
      expect(fresh.name, 'Trip');
      expect(fresh.monthlyAmount, 30000);
      expect(fresh.remainingAmount, 30000);
      expect(fresh.currency, 'USD');
      expect(fresh.color, '#123456');
      expect(fresh.icon, 'flight');
      final today = DateTime.now();
      expect(fresh.startDate, DateTime(today.year, today.month, today.day));
      expect(fresh.totalDays, 31);
      expect(prefs.getString(PreferenceKeys.activeBudgetId), newId);
    });

    test('creates a default period when there is no budget at all', () async {
      final result = await useCase.resetCurrentMonth();
      final id = (result as SettingsSuccess<String>).data;
      final created = await repository.getBudgetById(id);
      expect(created, isNotNull);
      expect(created!.name, 'Personal Budget');
      expect(created.currency, 'INR');
      expect(prefs.getString(PreferenceKeys.activeBudgetId), id);
    });
  });
}
