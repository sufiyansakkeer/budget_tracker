import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/database/app_database.dart';
import '../../../budget/domain/usecases/recalculate_remaining_amounts_usecase.dart';
import '../../../pay_later/domain/usecases/reconcile_tab_usecase.dart';
import 'data_codec.dart';

/// Metadata captured alongside a backup.
class BackupMetadata {
  final DateTime createdAt;
  final String appVersion;
  final int schemaVersion;

  const BackupMetadata({
    required this.createdAt,
    required this.appVersion,
    required this.schemaVersion,
  });
}

/// The file picked for Restore is a Monivo file, but not a backup: a data
/// export, which leaves out bills and is meant for Import. Its [message] is
/// written for people.
class WrongFileKindException implements Exception {
  final String message;

  const WrongFileKindException(this.message);

  @override
  String toString() => message;
}

/// Represents a validation error found during backup/restore validation.
class ValidationError {
  final String field;
  final String message;

  const ValidationError({required this.field, required this.message});

  @override
  String toString() => '$field: $message';
}

/// Handles full database backup and restore to/from a local JSON file.
///
/// Everything remains local — no cloud services.
///
/// The backup format is versioned and includes all application tables:
/// budgets, categories, expenses, settings, recurring expenses,
/// savings goals, bills, bill payments, and the four Pay later tables (tabs,
/// their purchases, payments and allocations).
///
/// Backups from before Pay later lack its keys; they restore with no tabs.
/// The format version stays at 2: a missing key reads as an empty list, and
/// an older app rejects a newer backup by its schema version, so it can never
/// restore one and silently drop the tabs.
class BackupService {
  static const int _backupFormatVersion = 2;

  /// Version string written when the platform version cannot be read (tests,
  /// or a failed platform channel). Never hard-code the real app version here;
  /// it comes from `package_info_plus` so it cannot drift from `pubspec.yaml`.
  static const String unknownAppVersion = 'unknown';

  final AppDatabase _database;
  final Future<String> Function() _appVersionResolver;

  /// Refreshes every budget's stored remaining amount after a restore,
  /// which writes expenses straight to the database.
  final RecalculateRemainingAmountsUseCase? _recalculateRemaining;

  /// Re-derives every tab's automatic allocations inside the restore's
  /// transaction, so a restore never leaves a payment half-applied.
  final ReconcileTabUseCase _reconcileTabs;

  BackupService({
    required AppDatabase database,
    required ReconcileTabUseCase reconcileTabs,
    Future<String> Function()? appVersionResolver,
    RecalculateRemainingAmountsUseCase? recalculateRemaining,
  }) : _database = database,
       _reconcileTabs = reconcileTabs,
       _appVersionResolver = appVersionResolver ?? _platformAppVersion,
       _recalculateRemaining = recalculateRemaining;

  static Future<String> _platformAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return unknownAppVersion;
    }
  }

  /// Builds the full backup payload (data + metadata) as a JSON-serializable
  /// map. This stays pure (no platform channels) so it can be unit tested.
  Future<Map<String, Object?>> buildBackupPayload() async {
    final data = await _collectData();
    final metadata = BackupMetadata(
      createdAt: DateTime.now(),
      appVersion: await _appVersionResolver(),
      schemaVersion: _database.schemaVersion,
    );
    return <String, Object?>{
      'type': 'monivo_backup',
      'backupFormatVersion': _backupFormatVersion,
      'metadata': {
        'createdAt': metadata.createdAt.toIso8601String(),
        'appVersion': metadata.appVersion,
        'schemaVersion': metadata.schemaVersion,
      },
      'data': data,
    };
  }

  /// Writes a full database backup to a temporary file and returns its
  /// path. The file still has to be delivered (saved or shared) to be of any
  /// use: the app's own storage is invisible to the user and to the system
  /// file picker Restore opens, and goes with an uninstall.
  Future<String> createBackup() async {
    final payload = await buildBackupPayload();
    final metadata = payload['metadata'] as Map<String, Object?>;
    final createdAt =
        DateTime.tryParse(metadata['createdAt']?.toString() ?? '') ??
        DateTime.now();

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${backupFileName(createdAt)}');

    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(payload));
    return file.path;
  }

  /// "monivo-backup-2026-10-10-1430.json": sorts by date in a folder and
  /// says what it is.
  static String backupFileName(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'monivo-backup-${at.year}-${two(at.month)}-${two(at.day)}-'
        '${two(at.hour)}${two(at.minute)}.json';
  }

  /// Whether [payload] is a Monivo data export rather than a backup: marked
  /// `monivo_export`, or (older exports) top-level records with no type.
  static bool isExport(Map<String, Object?> payload) =>
      payload['type'] == 'monivo_export' ||
      (payload['type'] == null &&
          payload['data'] == null &&
          payload['exportedAt'] != null &&
          (payload['expenses'] is List || payload['budgets'] is List));

  /// Validates a backup file without applying it. Returns a list of
  /// validation errors (empty if the backup is valid).
  Future<List<ValidationError>> validateBackup(String path) async {
    final errors = <ValidationError>[];

    final file = File(path);
    if (!await file.exists()) {
      errors.add(
        const ValidationError(field: 'file', message: 'Backup file not found.'),
      );
      return errors;
    }

    final raw = await file.readAsString();
    final Map<String, Object?> payload;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        errors.add(
          const ValidationError(
            field: 'format',
            message: 'Invalid backup format.',
          ),
        );
        return errors;
      }
      payload = decoded;
    } catch (e) {
      errors.add(
        ValidationError(field: 'format', message: 'Corrupted backup file: $e'),
      );
      return errors;
    }

    if (payload['type'] != 'monivo_backup') {
      errors.add(
        const ValidationError(
          field: 'type',
          message: 'Not a valid Monivo backup.',
        ),
      );
    }

    final meta = payload['metadata'];
    if (meta is! Map<String, Object?>) {
      errors.add(
        const ValidationError(
          field: 'metadata',
          message: 'Backup metadata missing.',
        ),
      );
    } else {
      final schemaVersion = (meta['schemaVersion'] as num?)?.toInt() ?? 0;
      if (schemaVersion > _database.schemaVersion) {
        errors.add(
          ValidationError(
            field: 'schemaVersion',
            message:
                'Backup schema v$schemaVersion is newer than supported '
                'v${_database.schemaVersion}.',
          ),
        );
      }
    }

    final data = payload['data'];
    if (data is! Map<String, Object?>) {
      errors.add(
        const ValidationError(field: 'data', message: 'Backup data missing.'),
      );
    } else {
      // Validate individual records
      _validateBudgetRecords(data, errors);
      _validateExpenseRecords(data, errors);
      _validateCategoryRecords(data, errors);
      _validateBillRecords(data, errors);
    }

    return errors;
  }

  /// Restores the database from a backup file at [path].
  ///
  /// Validates the payload and schema before applying. Returns the metadata
  /// that was restored.
  Future<BackupMetadata> restore(String path) async {
    await _rejectExport(path);
    // Validate first.
    final errors = await validateBackup(path);
    if (errors.isNotEmpty) {
      throw FormatException(
        'Backup validation failed:\n${errors.map((e) => '• ${e.message}').join('\n')}',
      );
    }

    final file = File(path);
    final raw = await file.readAsString();
    final Map<String, Object?> payload =
        jsonDecode(raw) as Map<String, Object?>;

    final meta = payload['metadata'] as Map<String, Object?>;
    final data = payload['data'] as Map<String, Object?>;

    developer.log(
      '[Database] Starting restore from backup (schema v'
      '${meta['schemaVersion']})',
      name: 'Database',
    );

    await _replaceAll(data);

    // The backup's stored remaining amounts may not match its expenses (an
    // older import, or a file edited by hand). The data is committed, so a
    // failure here is logged, not thrown.
    try {
      await _recalculateRemaining?.call();
    } catch (error, stackTrace) {
      developer.log(
        '[Database] Could not refresh budgets\' remaining amounts',
        name: 'Database',
        error: error,
        stackTrace: stackTrace,
      );
    }

    developer.log(
      '[Database] Restore completed successfully',
      name: 'Database',
    );

    return BackupMetadata(
      createdAt:
          DateTime.tryParse(meta['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      appVersion: meta['appVersion']?.toString() ?? 'unknown',
      schemaVersion: (meta['schemaVersion'] as num?)?.toInt() ?? 0,
    );
  }

  /// Throws [WrongFileKindException] when [path] holds a Monivo export, so
  /// Restore can say which action to use instead of calling it damaged.
  /// Anything unreadable is left to [validateBackup].
  Future<void> _rejectExport(String path) async {
    final file = File(path);
    if (!await file.exists()) return;
    Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } on FormatException {
      return;
    }
    if (decoded is Map<String, Object?> && isExport(decoded)) {
      throw const WrongFileKindException(
        'This is a Monivo export, not a backup, so it has no bills and '
        "can't replace your data. To add its records, use Import instead. "
        'Nothing was changed.',
      );
    }
  }

  /// Validates budget records in the backup data.
  void _validateBudgetRecords(
    Map<String, Object?> data,
    List<ValidationError> errors,
  ) {
    final budgets = (data['budgets'] as List?) ?? [];
    for (var i = 0; i < budgets.length; i++) {
      final item = budgets[i];
      if (item is! Map) {
        errors.add(
          ValidationError(
            field: 'budgets[$i]',
            message: 'Invalid budget record format.',
          ),
        );
        continue;
      }
      if (item['id'] == null || (item['id'] as String).isEmpty) {
        errors.add(
          ValidationError(
            field: 'budgets[$i].id',
            message: 'Budget record missing id.',
          ),
        );
      }
      final amount = (item['monthlyAmount'] as num?)?.toDouble();
      if (amount == null || !amount.isFinite || amount < 0) {
        errors.add(
          ValidationError(
            field: 'budgets[$i].monthlyAmount',
            message: 'Budget has invalid amount: ${item['monthlyAmount']}.',
          ),
        );
      }
      for (final key in const ['reservedAmount', 'savingsTarget']) {
        if (item[key] != null && item[key] is! num) {
          errors.add(
            ValidationError(
              field: 'budgets[$i].$key',
              message: 'Budget has invalid $key: ${item[key]}.',
            ),
          );
        }
      }
    }
  }

  /// Validates expense records in the backup data.
  void _validateExpenseRecords(
    Map<String, Object?> data,
    List<ValidationError> errors,
  ) {
    final expenses = (data['expenses'] as List?) ?? [];
    for (var i = 0; i < expenses.length; i++) {
      final item = expenses[i];
      if (item is! Map) {
        errors.add(
          ValidationError(
            field: 'expenses[$i]',
            message: 'Invalid expense record format.',
          ),
        );
        continue;
      }
      if (item['id'] == null || (item['id'] as String).isEmpty) {
        errors.add(
          ValidationError(
            field: 'expenses[$i].id',
            message: 'Expense record missing id.',
          ),
        );
      }
      final amount = (item['amount'] as num?)?.toDouble();
      if (amount == null || !amount.isFinite || amount <= 0) {
        errors.add(
          ValidationError(
            field: 'expenses[$i].amount',
            message: 'Expense has invalid amount: ${item['amount']}.',
          ),
        );
      }
      if (item['date'] != null) {
        final date = DateTime.tryParse(item['date'].toString());
        if (date == null) {
          errors.add(
            ValidationError(
              field: 'expenses[$i].date',
              message: 'Expense has invalid date: ${item['date']}.',
            ),
          );
        }
      }
      if (item['billId'] != null && item['billId'] is! String) {
        errors.add(
          ValidationError(
            field: 'expenses[$i].billId',
            message: 'Expense has invalid billId: ${item['billId']}.',
          ),
        );
      }
    }
  }

  /// Validates category records in the backup data.
  void _validateCategoryRecords(
    Map<String, Object?> data,
    List<ValidationError> errors,
  ) {
    final categories = (data['categories'] as List?) ?? [];
    for (var i = 0; i < categories.length; i++) {
      final item = categories[i];
      if (item is! Map) {
        errors.add(
          ValidationError(
            field: 'categories[$i]',
            message: 'Invalid category record format.',
          ),
        );
        continue;
      }
      if (item['id'] == null || (item['id'] as String).isEmpty) {
        errors.add(
          ValidationError(
            field: 'categories[$i].id',
            message: 'Category record missing id.',
          ),
        );
      }
    }
  }

  /// Validates bill records in the backup data.
  void _validateBillRecords(
    Map<String, Object?> data,
    List<ValidationError> errors,
  ) {
    final bills = (data['bills'] as List?) ?? [];
    for (var i = 0; i < bills.length; i++) {
      final item = bills[i];
      if (item is! Map) {
        errors.add(
          ValidationError(
            field: 'bills[$i]',
            message: 'Invalid bill record format.',
          ),
        );
        continue;
      }
      if (item['id'] == null || (item['id'] as String).isEmpty) {
        errors.add(
          ValidationError(
            field: 'bills[$i].id',
            message: 'Bill record missing id.',
          ),
        );
      }
      final amount = (item['amount'] as num?)?.toDouble();
      if (amount == null || !amount.isFinite || amount <= 0) {
        errors.add(
          ValidationError(
            field: 'bills[$i].amount',
            message: 'Bill has invalid amount: ${item['amount']}.',
          ),
        );
      }
      if (item['budgetId'] != null && item['budgetId'] is! String) {
        errors.add(
          ValidationError(
            field: 'bills[$i].budgetId',
            message: 'Bill has invalid budgetId: ${item['budgetId']}.',
          ),
        );
      }
    }
  }

  /// Every table, read in one transaction: a write landing mid-backup
  /// (e.g. the start-up reconcile) is either wholly in the file or not at
  /// all, so no row points at one the file lacks and the file restores.
  Future<Map<String, Object?>> _collectData() =>
      _database.transaction(_readAllTables);

  Future<Map<String, Object?>> _readAllTables() async {
    final expenses = await (_database.select(_database.expenses)).get();
    final categories = await (_database.select(_database.categories)).get();
    final budgets = await (_database.select(_database.budgets)).get();
    final settings = await (_database.select(_database.settings)).get();
    final recurringExpenses = await (_database.select(
      _database.recurringExpenses,
    )).get();
    final savingsGoals = await (_database.select(_database.savingsGoals)).get();
    final bills = await (_database.select(_database.bills)).get();
    final billPayments = await (_database.select(_database.billPayments)).get();
    final payLaterAccounts = await (_database.select(
      _database.payLaterAccounts,
    )).get();
    final payLaterEntries = await (_database.select(
      _database.payLaterEntries,
    )).get();
    final payLaterPayments = await (_database.select(
      _database.payLaterPayments,
    )).get();
    final payLaterAllocations = await (_database.select(
      _database.payLaterAllocations,
    )).get();

    return <String, Object?>{
      'budgets': budgets.map(DataCodec.encodeBudget).toList(),
      'categories': categories.map(DataCodec.encodeCategory).toList(),
      'expenses': expenses.map(DataCodec.encodeExpense).toList(),
      'settings': {for (final s in settings) s.key: s.value},
      'recurringExpenses': recurringExpenses
          .map(DataCodec.encodeRecurringExpense)
          .toList(),
      'savingsGoals': savingsGoals.map(DataCodec.encodeSavingsGoal).toList(),
      'bills': bills.map(DataCodec.encodeBill).toList(),
      'billPayments': billPayments.map(DataCodec.encodeBillPayment).toList(),
      'payLaterAccounts': payLaterAccounts
          .map(DataCodec.encodePayLaterAccount)
          .toList(),
      'payLaterEntries': payLaterEntries
          .map(DataCodec.encodePayLaterEntry)
          .toList(),
      'payLaterPayments': payLaterPayments
          .map(DataCodec.encodePayLaterPayment)
          .toList(),
      'payLaterAllocations': payLaterAllocations
          .map(DataCodec.encodePayLaterAllocation)
          .toList(),
    };
  }

  /// Replaces all table contents with the data from a backup payload, then
  /// reconciles every tab. The operation is atomic — either all tables are
  /// updated and reconciled, or none.
  Future<void> _replaceAll(Map<String, Object?> data) async {
    await _database.transaction(() async {
      // Clear in dependency order (children before parents). Pay later rows
      // go first: entries point at expenses, and nothing cascades to tabs.
      await (_database.delete(_database.payLaterAllocations)).go();
      await (_database.delete(_database.payLaterPayments)).go();
      await (_database.delete(_database.payLaterEntries)).go();
      await (_database.delete(_database.payLaterAccounts)).go();
      await (_database.delete(_database.billPayments)).go();
      await (_database.delete(_database.expenses)).go();
      await (_database.delete(_database.bills)).go();
      await (_database.delete(_database.recurringExpenses)).go();
      await (_database.delete(_database.savingsGoals)).go();
      await (_database.delete(_database.categories)).go();
      await (_database.delete(_database.budgets)).go();
      await (_database.delete(_database.settings)).go();

      List<Map> records(String key) => [
        for (final item in (data[key] as List?) ?? const []) item as Map,
      ];

      final budgets = records('budgets');
      // Bills may only link to a budget this backup restores: with foreign
      // keys on, one dangling link would roll back the whole restore.
      final restoredBudgetIds = {for (final map in budgets) map['id']};
      for (final map in budgets) {
        await _database
            .into(_database.budgets)
            .insert(DataCodec.decodeBudget(map));
      }
      for (final map in records('categories')) {
        await _database
            .into(_database.categories)
            .insert(DataCodec.decodeCategory(map));
      }
      for (final map in records('expenses')) {
        await _database
            .into(_database.expenses)
            .insert(
              DataCodec.decodeExpense(
                map,
                budgetId: (map['budgetId'] as String?) ?? '',
              ),
            );
      }

      final settings = (data['settings'] as Map?) ?? const {};
      for (final entry in settings.entries) {
        await _database
            .into(_database.settings)
            .insertOnConflictUpdate(
              SettingsCompanion.insert(
                key: entry.key as String,
                value: entry.value.toString(),
              ),
            );
      }

      for (final map in records('recurringExpenses')) {
        await _database
            .into(_database.recurringExpenses)
            .insert(DataCodec.decodeRecurringExpense(map));
      }
      for (final map in records('savingsGoals')) {
        await _database
            .into(_database.savingsGoals)
            .insert(DataCodec.decodeSavingsGoal(map));
      }
      for (final map in records('bills')) {
        await _database
            .into(_database.bills)
            .insert(
              DataCodec.decodeBill(
                map,
                budgetId: restoredBudgetIds.contains(map['budgetId'])
                    ? map['budgetId'] as String
                    : null,
              ),
            );
      }
      for (final map in records('billPayments')) {
        await _database
            .into(_database.billPayments)
            .insert(DataCodec.decodeBillPayment(map));
      }

      // Pay later, parents first and after the expenses its entries point
      // at. A backup from before Pay later has none of these keys.
      for (final map in records('payLaterAccounts')) {
        await _database
            .into(_database.payLaterAccounts)
            .insert(DataCodec.decodePayLaterAccount(map));
      }
      for (final map in records('payLaterEntries')) {
        await _database
            .into(_database.payLaterEntries)
            .insert(DataCodec.decodePayLaterEntry(map));
      }
      for (final map in records('payLaterPayments')) {
        await _database
            .into(_database.payLaterPayments)
            .insert(DataCodec.decodePayLaterPayment(map));
      }
      for (final map in records('payLaterAllocations')) {
        await _database
            .into(_database.payLaterAllocations)
            .insert(DataCodec.decodePayLaterAllocation(map));
      }

      // Re-derive the automatic allocations from what was restored (a file
      // edited by hand, or written mid-change). Its own transaction nests
      // here as a savepoint, so a failure rolls the whole restore back.
      await _reconcileTabs.all();
    });
  }
}
