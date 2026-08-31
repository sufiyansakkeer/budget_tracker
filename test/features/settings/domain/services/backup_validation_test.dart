import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/features/settings/domain/services/backup_service.dart';

import '../../../../helpers/in_memory_database.dart';

void main() {
  late AppDatabase database;
  late BackupService service;

  setUp(() async {
    database = await createInMemoryDatabase();
    service = BackupService(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  group('BackupService validateBackup', () {
    test('returns error for non-existent file', () async {
      final errors = await service.validateBackup('/nonexistent/file.json');
      expect(errors.length, 1);
      expect(errors.first.field, 'file');
    });

    test('returns error for corrupted JSON', () async {
      final file = File('${Directory.systemTemp.path}/corrupt.json');
      await file.writeAsString('{invalid json}');

      final errors = await service.validateBackup(file.path);
      expect(errors.length, 1);
      expect(errors.first.field, 'format');
    });

    test('returns error for non-backup JSON', () async {
      final file = File('${Directory.systemTemp.path}/notbackup.json');
      await file.writeAsString(jsonEncode({'some': 'data'}));

      final errors = await service.validateBackup(file.path);
      expect(errors.any((e) => e.field == 'type'), isTrue);
    });

    test('returns error for newer schema version', () async {
      final payload = {
        'type': 'monivo_backup',
        'metadata': {'schemaVersion': 99},
        'data': <String, Object?>{},
      };
      final file = File('${Directory.systemTemp.path}/newer.json');
      await file.writeAsString(jsonEncode(payload));

      final errors = await service.validateBackup(file.path);
      expect(errors.any((e) => e.field == 'schemaVersion'), isTrue);
    });

    test('validates budget records with invalid amounts', () async {
      final payload = {
        'type': 'monivo_backup',
        'metadata': {'schemaVersion': 4},
        'data': {
          'budgets': [
            {'id': 'budget-1', 'monthlyAmount': -100},
          ],
        },
      };
      final file = File('${Directory.systemTemp.path}/bad_amounts.json');
      await file.writeAsString(jsonEncode(payload));

      final errors = await service.validateBackup(file.path);
      expect(errors.any((e) => e.field.contains('monthlyAmount')), isTrue);
    });

    test('validates expense records with invalid amounts', () async {
      final payload = {
        'type': 'monivo_backup',
        'metadata': {'schemaVersion': 4},
        'data': {
          'expenses': [
            {
              'id': 'exp-1',
              'amount': 0,
              'date': DateTime(2026, 8, 1).toIso8601String(),
            },
          ],
        },
      };
      final file = File('${Directory.systemTemp.path}/bad_exp_amounts.json');
      await file.writeAsString(jsonEncode(payload));

      final errors = await service.validateBackup(file.path);
      expect(errors.any((e) => e.field.contains('amount')), isTrue);
    });

    test('validates expense records with invalid dates', () async {
      final payload = {
        'type': 'monivo_backup',
        'metadata': {'schemaVersion': 4},
        'data': {
          'expenses': [
            {'id': 'exp-1', 'amount': 100, 'date': 'not-a-date'},
          ],
        },
      };
      final file = File('${Directory.systemTemp.path}/bad_dates.json');
      await file.writeAsString(jsonEncode(payload));

      final errors = await service.validateBackup(file.path);
      expect(errors.any((e) => e.field.contains('date')), isTrue);
    });

    test('passes validation for valid backup', () async {
      final payload = {
        'type': 'monivo_backup',
        'metadata': {'schemaVersion': 4},
        'data': {
          'budgets': [
            {
              'id': 'budget-1',
              'name': 'Test',
              'monthlyAmount': 10000,
              'remainingAmount': 5000,
              'currency': 'INR',
              'startDate': DateTime(2026, 8, 1).toIso8601String(),
              'endDate': DateTime(2026, 8, 31).toIso8601String(),
              'isArchived': false,
              'createdAt': DateTime(2026, 8, 1).toIso8601String(),
              'updatedAt': DateTime(2026, 8, 1).toIso8601String(),
            },
          ],
          'expenses': [
            {
              'id': 'exp-1',
              'amount': 100,
              'date': DateTime(2026, 8, 5).toIso8601String(),
            },
          ],
        },
      };
      final file = File('${Directory.systemTemp.path}/valid.json');
      await file.writeAsString(jsonEncode(payload));

      final errors = await service.validateBackup(file.path);
      expect(errors, isEmpty);
    });
  });

  group('BackupService buildBackupPayload', () {
    test('includes all table types in backup', () async {
      final payload = await service.buildBackupPayload();

      expect(payload['type'], 'monivo_backup');
      expect(payload.containsKey('backupFormatVersion'), isTrue);
      expect(payload.containsKey('metadata'), isTrue);
      expect(payload.containsKey('data'), isTrue);

      final data = payload['data'] as Map<String, Object?>;
      expect(data.containsKey('budgets'), isTrue);
      expect(data.containsKey('categories'), isTrue);
      expect(data.containsKey('expenses'), isTrue);
      expect(data.containsKey('settings'), isTrue);
      expect(data.containsKey('recurringExpenses'), isTrue);
      expect(data.containsKey('savingsGoals'), isTrue);
      expect(data.containsKey('bills'), isTrue);
      expect(data.containsKey('billPayments'), isTrue);
    });
  });

  group('BackupService restore', () {
    test('rejects backup with invalid records', () async {
      final payload = {
        'type': 'monivo_backup',
        'metadata': {'schemaVersion': 4},
        'data': {
          'budgets': [
            {
              'id': 'budget-1',
              'monthlyAmount': -100, // Invalid
            },
          ],
        },
      };
      final file = File('${Directory.systemTemp.path}/invalid_restore.json');
      await file.writeAsString(jsonEncode(payload));

      expect(() => service.restore(file.path), throwsFormatException);
    });

    test('successfully restores valid backup', () async {
      final payload = {
        'type': 'monivo_backup',
        'metadata': {'schemaVersion': 4},
        'data': {
          'budgets': [
            {
              'id': 'budget-restored',
              'name': 'Restored Budget',
              'monthlyAmount': 15000,
              'remainingAmount': 10000,
              'currency': 'INR',
              'startDate': DateTime(2026, 9, 1).toIso8601String(),
              'endDate': DateTime(2026, 9, 30).toIso8601String(),
              'isArchived': false,
              'createdAt': DateTime(2026, 9, 1).toIso8601String(),
              'updatedAt': DateTime(2026, 9, 1).toIso8601String(),
            },
          ],
          'categories': [
            {
              'id': 'food',
              'name': 'Food',
              'icon': 'restaurant',
              'colorHex': '#FF6B6B',
              'isSystem': true,
            },
          ],
          'expenses': [],
          'settings': {},
          'recurringExpenses': [],
          'savingsGoals': [],
          'bills': [],
          'billPayments': [],
        },
      };
      final file = File('${Directory.systemTemp.path}/valid_restore.json');
      await file.writeAsString(jsonEncode(payload));

      final metadata = await service.restore(file.path);
      expect(metadata.schemaVersion, 4);

      // Verify the budget was restored.
      final budgets = await (database.select(database.budgets)).get();
      expect(budgets.length, 1);
      expect(budgets.first.id, 'budget-restored');
      expect(budgets.first.monthlyAmount, 15000);
    });
  });
}
