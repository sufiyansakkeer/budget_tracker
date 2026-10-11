import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/features/settings/domain/entities/settings_failure.dart';
import 'package:monivo/features/settings/domain/services/backup_service.dart';
import 'package:monivo/features/settings/domain/services/export_service.dart';
import 'package:monivo/features/settings/domain/services/file_delivery_service.dart';
import 'package:monivo/features/settings/domain/usecases/backup_data_usecase.dart';
import 'package:monivo/features/settings/domain/usecases/restore_data_usecase.dart';

import '../../../../helpers/in_memory_database.dart';

/// UX-002: "Back up" wrote a file into the app's private storage and said
/// "Backup created." — the user could never reach it. UX-003: the JSON
/// export was named and shared as a backup, and Restore rejected it as
/// damaged.
void main() {
  late AppDatabase database;

  setUp(() async => database = await createInMemoryDatabase());
  tearDown(() async => database.close());

  Future<void> seed() async {
    await database
        .into(database.budgets)
        .insert(
          BudgetsCompanion.insert(
            id: 'budget-1',
            name: 'Personal',
            monthlyAmount: 50000,
            remainingAmount: 50000,
            currency: 'INR',
            startDate: DateTime(2024, 1, 1),
            endDate: DateTime(2024, 1, 31),
          ),
        );
    await database
        .into(database.expenses)
        .insert(
          ExpensesCompanion.insert(
            id: 'exp-1',
            budgetId: 'budget-1',
            amount: 300,
            categoryId: 'food',
            date: DateTime(2024, 1, 10),
          ),
        );
  }

  group('UX-002: a backup is delivered, and the outcome reported as it is', () {
    for (final outcome in FileDeliveryOutcome.values) {
      test('$outcome passes through unchanged', () async {
        await seed();
        final delivery = _Delivery(outcome);
        final useCase = BackupDataUseCase(
          backupService: _TempBackupService(database),
          delivery: delivery,
        );

        final result = await useCase(destination: FileDestination.device);

        expect((result as SettingsSuccess).data, outcome);
        expect(delivery.destination, FileDestination.device);
        expect(delivery.fileName, startsWith('monivo-backup-'));
        expect(delivery.extension, 'json');
        // The delivered file is a real, restorable backup.
        final payload = jsonDecode(await delivery.file!.readAsString()) as Map;
        expect(payload['type'], 'monivo_backup');
      });
    }

    test('a failed delivery is an error, never "saved"', () async {
      final useCase = BackupDataUseCase(
        backupService: _TempBackupService(database),
        delivery: _Delivery(FileDeliveryOutcome.saved, fail: true),
      );

      final result = await useCase(destination: FileDestination.share);

      expect(result, isA<SettingsError>());
      expect(
        (result as SettingsError).failure.type,
        SettingsErrorType.backupFailure,
      );
    });

    test('the file name says what it is and sorts by date', () {
      expect(
        BackupService.backupFileName(DateTime(2026, 10, 9, 7, 5)),
        'monivo-backup-2026-10-09-0705.json',
      );
    });
  });

  group('UX-003: exports and backups are told apart', () {
    test('a data export is marked as one', () async {
      final data = await ExportService(database: database).collectJsonData();
      expect(data['type'], 'monivo_export');
      expect(BackupService.isExport(data), isTrue);
    });

    test('an export from before the marker is recognised by its shape', () {
      expect(
        BackupService.isExport({
          'schemaVersion': 8,
          'exportedAt': '2026-10-01T10:00:00.000',
          'expenses': <Object?>[],
        }),
        isTrue,
      );
    });

    test('Restore refuses an export with a message naming Import, and '
        'changes nothing', () async {
      await seed();
      final data = await ExportService(database: database).collectJsonData();
      final file = File('${Directory.systemTemp.path}/ux003_export.json');
      await file.writeAsString(jsonEncode(data));
      final useCase = RestoreDataUseCase(
        backupService: BackupService(database: database),
      );

      final result = await useCase(file.path);

      final failure = (result as SettingsError).failure;
      expect(failure.type, SettingsErrorType.wrongFileKind);
      expect(failure.message, contains('use Import instead'));
      expect(failure.message, contains('Nothing was changed'));
      expect(await (database.select(database.expenses)).get(), hasLength(1));
    });

    test('a real backup still restores', () async {
      await seed();
      final payload = await BackupService(
        database: database,
      ).buildBackupPayload();
      final file = File('${Directory.systemTemp.path}/ux003_backup.json');
      await file.writeAsString(jsonEncode(payload));

      final result = await RestoreDataUseCase(
        backupService: BackupService(database: database),
      )(file.path);

      expect(result, isA<SettingsSuccess>());
    });
  });
}

/// Writes the backup to the system temp folder; the real one asks
/// path_provider, which tests do not have.
class _TempBackupService extends BackupService {
  _TempBackupService(AppDatabase database)
    : super(database: database, appVersionResolver: () async => '1.0.0');

  @override
  Future<String> createBackup() async {
    final payload = await buildBackupPayload();
    final file = File(
      '${Directory.systemTemp.path}/'
      '${BackupService.backupFileName(DateTime(2026, 10, 10, 9))}',
    );
    await file.writeAsString(jsonEncode(payload));
    return file.path;
  }
}

class _Delivery extends FileDeliveryService {
  final FileDeliveryOutcome outcome;
  final bool fail;
  File? file;
  String? fileName;
  String? extension;
  FileDestination? destination;

  _Delivery(this.outcome, {this.fail = false});

  @override
  Future<FileDeliveryOutcome> deliver({
    required File file,
    required String fileName,
    required String mimeType,
    required String extension,
    required FileDestination destination,
    String? shareText,
  }) async {
    if (fail) throw const FileSystemException('no space left');
    this.file = file;
    this.fileName = fileName;
    this.extension = extension;
    this.destination = destination;
    return outcome;
  }
}
