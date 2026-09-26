import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/constants/preference_keys.dart';
import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/budget/data/datasource/budget_local_datasource_impl.dart';
import 'package:monivo/features/budget/data/repository/budget_repository_impl.dart';
import 'package:monivo/features/budget/domain/entities/budget_error.dart';
import 'package:monivo/features/budget/domain/repository/budget_repository.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/in_memory_database.dart';

/// The active-budget id is a preference; budgets are rows. These tests pin
/// down what the repository does when the two disagree, and that the budget
/// period is judged by calendar day.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late SharedPreferences prefs;
  late BudgetRepositoryImpl repository;

  BudgetEntity budget(
    String id, {
    DateTime? start,
    DateTime? end,
    bool archived = false,
  }) {
    final now = DateTime(2026, 9, 1, 10);
    final s = start ?? DateTime(2026, 9, 1);
    return BudgetEntity(
      id: id,
      name: id,
      monthlyAmount: 1000,
      remainingAmount: 1000,
      currency: 'INR',
      startDate: s,
      endDate: end ?? s.add(const Duration(days: 29)),
      isArchived: archived,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> open({Map<String, Object> prefValues = const {}}) async {
    SharedPreferences.setMockInitialValues(prefValues);
    prefs = await SharedPreferences.getInstance();
    database = await createInMemoryDatabase();
    repository = BudgetRepositoryImpl(
      localDataSource: BudgetLocalDataSourceImpl(
        database: database,
        sharedPreferences: prefs,
      ),
      calculationService: BudgetCalculationService(),
    );
  }

  tearDown(() => database.close());

  group('getActiveBudgetId', () {
    test('returns the stored id when it references a budget', () async {
      await open(prefValues: {PreferenceKeys.activeBudgetId: 'a'});
      await repository.createBudget(budget('a'));
      await repository.createBudget(budget('b', start: DateTime(2026, 9, 10)));

      expect(await repository.getActiveBudgetId(), 'a');
      expect(prefs.getString(PreferenceKeys.activeBudgetId), 'a');
    });

    test('falls back to the newest non-archived budget when the stored id is '
        'stale, and persists the choice', () async {
      await open(prefValues: {PreferenceKeys.activeBudgetId: 'deleted'});
      await repository.createBudget(budget('older'));
      await repository.createBudget(
        budget('newer', start: DateTime(2026, 9, 10)),
      );
      await repository.createBudget(
        budget('archived', start: DateTime(2026, 9, 20), archived: true),
      );

      expect(await repository.getActiveBudgetId(), 'newer');
      expect(prefs.getString(PreferenceKeys.activeBudgetId), 'newer');
      expect((await repository.getActiveBudget())?.id, 'newer');
    });

    test(
      'falls back to the newest budget when every budget is archived',
      () async {
        await open();
        await repository.createBudget(budget('old', archived: true));
        await repository.createBudget(
          budget('recent', start: DateTime(2026, 9, 15), archived: true),
        );

        expect(await repository.getActiveBudgetId(), 'recent');
      },
    );

    test('returns null when there are no budgets at all', () async {
      await open(prefValues: {PreferenceKeys.activeBudgetId: 'gone'});

      expect(await repository.getActiveBudgetId(), isNull);
      expect(await repository.getActiveBudget(), isNull);
    });

    test('deleting the active budget hands over to another one', () async {
      await open();
      await repository.createBudget(budget('first'));
      await repository.createBudget(
        budget('second', start: DateTime(2026, 9, 5)),
      );
      await repository.setActiveBudgetId('second');

      await repository.deleteBudget('second');

      expect(await repository.getActiveBudgetId(), 'first');
    });
  });

  group('getCalculationContext period check', () {
    test('accepts any time on the first and last day of the period', () async {
      await open();
      // Onboarding stores the creation instant, not midnight.
      final created = budget(
        'b',
        start: DateTime(2026, 9, 1, 12, 16, 15),
        end: DateTime(2026, 10, 1, 12, 16, 15),
      );
      await repository.createBudget(created);

      for (final date in [
        DateTime(2026, 9, 1, 8), // first day, before the stored time
        DateTime(2026, 10, 1, 23, 30), // last day, after the stored time
        DateTime(2026, 9, 15),
      ]) {
        final result = await repository.getCalculationContext(
          'b',
          referenceDate: date,
        );
        expect(
          result,
          isA<BudgetSuccess<BudgetCalculationContext>>(),
          reason: '$date should be inside the period',
        );
      }
    });

    test('rejects dates outside the period', () async {
      await open();
      await repository.createBudget(
        budget(
          'b',
          start: DateTime(2026, 9, 1, 12),
          end: DateTime(2026, 10, 1, 12),
        ),
      );

      for (final date in [
        DateTime(2026, 8, 31, 23, 59),
        DateTime(2026, 10, 2, 0, 1),
      ]) {
        final result = await repository.getCalculationContext(
          'b',
          referenceDate: date,
        );
        expect(result, isA<BudgetError<BudgetCalculationContext>>());
        expect(
          (result as BudgetError).failure.type,
          BudgetErrorType.invalidDate,
        );
      }
    });
  });
}
