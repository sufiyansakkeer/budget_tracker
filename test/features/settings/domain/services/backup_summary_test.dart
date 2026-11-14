import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/features/settings/domain/entities/settings_failure.dart';
import 'package:monivo/features/settings/domain/services/backup_service.dart';
import 'package:monivo/features/settings/domain/services/export_service.dart';
import 'package:monivo/features/settings/domain/usecases/restore_data_usecase.dart';

import '../../../../helpers/in_memory_database.dart';
import '../../../../helpers/pay_later_fixtures.dart';

/// UX-041: Restore asked to replace everything without saying which file
/// was picked. The backup is read (never written) first, so the
/// confirmation can describe it, and a wrong file is refused before it.
void main() {
  late AppDatabase database;
  late RestoreDataUseCase useCase;

  setUp(() async {
    database = await createInMemoryDatabase();
    useCase = RestoreDataUseCase(
      backupService: BackupService(
        database: database,
        reconcileTabs: reconcileTabsOn(database),
      ),
    );
  });
  tearDown(() async => database.close());

  Future<void> seed() async {
    for (final id in ['b1', 'b2']) {
      await database
          .into(database.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: id,
              name: 'Budget $id',
              monthlyAmount: 500,
              remainingAmount: 500,
              currency: 'USD',
              startDate: DateTime(2024, 1, 1),
              endDate: DateTime(2024, 1, 31),
            ),
          );
    }
    for (final id in ['e1', 'e2', 'e3']) {
      await database
          .into(database.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: id,
              budgetId: 'b1',
              amount: 3,
              categoryId: 'food',
              date: DateTime(2024, 1, 10),
            ),
          );
    }
  }

  Future<String> write(String name, Map<String, Object?> payload) async {
    final file = File('${Directory.systemTemp.path}/ux041_$name.json');
    await file.writeAsString(jsonEncode(payload));
    addTearDown(() => file.delete());
    return file.path;
  }

  test('says what the backup holds and when it was made, writing '
      'nothing', () async {
    await seed();
    final payload = await BackupService(
      database: database,
      reconcileTabs: reconcileTabsOn(database),
    ).buildBackupPayload();
    (payload['metadata'] as Map<String, Object?>)['createdAt'] = DateTime(
      2026,
      10,
      3,
      14,
      30,
    ).toIso8601String();
    final path = await write('backup', payload);
    // The data on the device differs from the file's.
    await database.delete(database.expenses).go();

    final result = await useCase.preview(path);

    final summary = (result as SettingsSuccess<BackupSummary>).data;
    expect(summary.createdAt, DateTime(2026, 10, 3, 14, 30));
    expect(summary.budgets, 2);
    expect(summary.expenses, 3);
    expect(summary.bills, 0);
    expect(await database.select(database.expenses).get(), isEmpty);
  });

  test('an export is refused before the confirmation', () async {
    await seed();
    final data = await ExportService(database: database).collectJsonData();
    final path = await write('export', data);

    final result = await useCase.preview(path);

    expect(
      (result as SettingsError).failure.type,
      SettingsErrorType.wrongFileKind,
    );
  });

  test('a damaged file is refused before the confirmation', () async {
    final path = await write('damaged', {'type': 'monivo_backup'});

    final result = await useCase.preview(path);

    expect(
      (result as SettingsError).failure.type,
      SettingsErrorType.invalidData,
    );
  });
}
