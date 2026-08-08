import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_tracker/core/database/app_database.dart';
import 'package:budget_tracker/features/settings/domain/services/export_service.dart';

import '../../../../helpers/in_memory_database.dart';

void main() {
  late AppDatabase database;
  late ExportService exportService;

  setUp(() async {
    database = await createInMemoryDatabase();
    exportService = ExportService(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> seedExpense() async {
    final now = DateTime(2024, 1, 10, 12, 0);
    await database
        .into(database.budgets)
        .insert(
          BudgetsCompanion.insert(
            id: 'budget-1',
            name: 'Personal',
            monthlyAmount: 50000,
            remainingAmount: 40000,
            currency: 'INR',
            startDate: DateTime(2024, 1, 1),
            endDate: DateTime(2024, 1, 31),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await database
        .into(database.categories)
        .insert(
          CategoriesCompanion.insert(
            id: 'food',
            name: 'Food',
            icon: 'restaurant',
            colorHex: '#FF6B6B',
          ),
        );
    await database
        .into(database.expenses)
        .insert(
          ExpensesCompanion.insert(
            id: 'exp-1',
            budgetId: 'budget-1',
            amount: 100.0,
            categoryId: 'food',
            note: const Value('Lunch'),
            date: now,
            time: Value(now),
            tags: const Value('["meal"]'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  group('ExportService', () {
    test('collectCsvRows includes expense data', () async {
      await seedExpense();

      final rows = await exportService.collectCsvRows();

      expect(rows.length, greaterThan(2));
      expect(rows.any((r) => r.contains('exp-1')), isTrue);
      expect(rows.any((r) => r.contains('Lunch')), isTrue);
    });

    test('collectCsvRows handles empty database gracefully', () async {
      final rows = await exportService.collectCsvRows();

      expect(rows.length, greaterThan(2));
      expect(rows.any((r) => r.contains('exp-1')), isFalse);
    });

    test('collectJsonData includes schema version and settings', () async {
      await database
          .into(database.settings)
          .insert(SettingsCompanion.insert(key: 'themeMode', value: 'dark'));

      final data = await exportService.collectJsonData();

      expect(data['schemaVersion'], database.schemaVersion);
      expect(data.containsKey('budgets'), isTrue);
      expect(data.containsKey('categories'), isTrue);
      expect(data.containsKey('expenses'), isTrue);
      expect(data['settings'], containsPair('themeMode', 'dark'));
    });
  });
}
