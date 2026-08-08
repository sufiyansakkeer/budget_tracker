import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_tracker/core/database/app_database.dart';
import 'package:budget_tracker/features/settings/domain/services/backup_service.dart';

import '../../../../helpers/in_memory_database.dart';

void main() {
  late AppDatabase database;
  late BackupService backupService;

  setUp(() async {
    database = await createInMemoryDatabase();
    backupService = BackupService(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> seedData() async {
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
            amount: 1000,
            categoryId: 'food',
            note: Value('Lunch'),
            date: now,
            time: Value(now),
            tags: Value('["meal"]'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    await database
        .into(database.settings)
        .insert(SettingsCompanion.insert(key: 'themeMode', value: 'dark'));
  }

  group('BackupService', () {
    test('buildBackupPayload collects all data', () async {
      await seedData();

      final payload = await backupService.buildBackupPayload();

      expect(payload['type'], 'budget_tracker_backup');

      final metadata = payload['metadata'] as Map<String, Object?>;
      expect(metadata['schemaVersion'], database.schemaVersion);

      final data = payload['data'] as Map<String, Object?>;
      final budgets = data['budgets'] as List;
      final expenses = data['expenses'] as List;
      final settings = data['settings'] as Map;

      expect(budgets.any((b) => (b as Map)['id'] == 'budget-1'), isTrue);
      expect(expenses.any((e) => (e as Map)['id'] == 'exp-1'), isTrue);
      expect(settings['themeMode'], 'dark');
    });

    test('restore rejects a backup with a newer schema version', () async {
      final file = File('${Directory.systemTemp.path}/bad_backup.json');
      await file.writeAsString(
        '{"type":"budget_tracker_backup","metadata":{"schemaVersion":99},'
        '"data":{"budgets":[],"categories":[],"expenses":[],"settings":{}}}',
      );

      expect(() => backupService.restore(file.path), throwsFormatException);
    });

    test('restore handles a corrupted backup file', () async {
      final file = File('${Directory.systemTemp.path}/corrupt.json');
      await file.writeAsString('not valid json {');

      expect(() => backupService.restore(file.path), throwsFormatException);
    });

    test('restore rejects a file that is not a backup', () async {
      final file = File('${Directory.systemTemp.path}/other.json');
      await file.writeAsString('{"type":"other","data":{}}');

      expect(() => backupService.restore(file.path), throwsFormatException);
    });

    test('restore applies data from a valid backup', () async {
      final payload = {
        'type': 'budget_tracker_backup',
        'metadata': {'schemaVersion': 2, 'appVersion': '1.0.0'},
        'data': {
          'budgets': [
            {
              'id': 'restored-budget',
              'name': 'Trip',
              'monthlyAmount': 1000,
              'remainingAmount': 900,
              'currency': 'USD',
              'startDate': DateTime(2024, 2, 1).toIso8601String(),
              'endDate': DateTime(2024, 2, 29).toIso8601String(),
              'isArchived': false,
              'createdAt': DateTime(2024, 2, 1).toIso8601String(),
              'updatedAt': DateTime(2024, 2, 1).toIso8601String(),
            },
          ],
          'categories': [
            {
              'id': 'food',
              'name': 'Food',
              'icon': 'restaurant',
              'colorHex': '#FF0000',
              'isSystem': true,
            },
          ],
          'expenses': <Object?>[],
          'settings': {'themeMode': 'light'},
        },
      };

      final file = File('${Directory.systemTemp.path}/valid_backup.json');
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
      );

      final metadata = await backupService.restore(file.path);

      expect(metadata.schemaVersion, 2);
      expect(metadata.appVersion, '1.0.0');

      final budgets = await (database.select(database.budgets)).get();
      expect(budgets.length, 1);
      expect(budgets.first.id, 'restored-budget');

      final settings = await (database.select(database.settings)).get();
      expect(settings, hasLength(1));
      expect(settings.first.value, 'light');
    });
  });
}
