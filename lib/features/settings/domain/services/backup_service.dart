import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/database/app_database.dart';

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
/// savings goals, bills, and bill payments.
class BackupService {
  static const String _appVersion = '1.2.2';
  static const int _backupFormatVersion = 2;

  final AppDatabase _database;

  BackupService({required AppDatabase database}) : _database = database;

  /// Builds the full backup payload (data + metadata) as a JSON-serializable
  /// map. This stays pure (no platform channels) so it can be unit tested.
  Future<Map<String, Object?>> buildBackupPayload() async {
    final data = await _collectData();
    final metadata = BackupMetadata(
      createdAt: DateTime.now(),
      appVersion: _appVersion,
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

  /// Creates a full database backup file in the documents directory.
  Future<String> createBackup() async {
    final payload = await buildBackupPayload();
    final metadata = payload['metadata'] as Map<String, Object?>;
    final createdAt =
        DateTime.tryParse(metadata['createdAt']?.toString() ?? '') ??
        DateTime.now();

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = createdAt.millisecondsSinceEpoch;
    final file = File('${directory.path}/backup_$timestamp.json');

    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(payload));
    return file.path;
  }

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
    }
  }

  Future<Map<String, Object?>> _collectData() async {
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

    return <String, Object?>{
      'budgets': budgets
          .map(
            (b) => {
              'id': b.id,
              'name': b.name,
              'monthlyAmount': b.monthlyAmount,
              'remainingAmount': b.remainingAmount,
              'currency': b.currency,
              'startDate': b.startDate.toIso8601String(),
              'endDate': b.endDate.toIso8601String(),
              'isArchived': b.isArchived,
              'color': b.color,
              'icon': b.icon,
              'notes': b.notes,
              'createdAt': b.createdAt.toIso8601String(),
              'updatedAt': b.updatedAt.toIso8601String(),
            },
          )
          .toList(),
      'categories': categories
          .map(
            (c) => {
              'id': c.id,
              'name': c.name,
              'icon': c.icon,
              'colorHex': c.colorHex,
              'isSystem': c.isSystem,
            },
          )
          .toList(),
      'expenses': expenses
          .map(
            (e) => {
              'id': e.id,
              'budgetId': e.budgetId,
              'amount': e.amount,
              'categoryId': e.categoryId,
              'note': e.note,
              'date': e.date.toIso8601String(),
              'time': e.time.toIso8601String(),
              'receiptImagePath': e.receiptImagePath,
              'tags': e.tags,
              'createdAt': e.createdAt.toIso8601String(),
              'updatedAt': e.updatedAt.toIso8601String(),
            },
          )
          .toList(),
      'settings': {for (final s in settings) s.key: s.value},
      'recurringExpenses': recurringExpenses
          .map(
            (r) => {
              'id': r.id,
              'title': r.title,
              'amount': r.amount,
              'categoryId': r.categoryId,
              'frequency': r.frequency,
              'nextDueDate': r.nextDueDate.toIso8601String(),
              'isActive': r.isActive,
            },
          )
          .toList(),
      'savingsGoals': savingsGoals
          .map(
            (g) => {
              'id': g.id,
              'title': g.title,
              'targetAmount': g.targetAmount,
              'currentAmount': g.currentAmount,
              'targetDate': g.targetDate.toIso8601String(),
            },
          )
          .toList(),
      'bills': bills
          .map(
            (b) => {
              'id': b.id,
              'title': b.title,
              'note': b.note,
              'amount': b.amount,
              'currency': b.currency,
              'category': b.category,
              'dueDate': b.dueDate.toIso8601String(),
              'dueTime': b.dueTime?.toIso8601String(),
              'isRecurring': b.isRecurring,
              'recurrenceType': b.recurrenceType,
              'recurrenceInterval': b.recurrenceInterval,
              'reminderEnabled': b.reminderEnabled,
              'reminderOffsetDays': b.reminderOffsetDays,
              'isPaid': b.isPaid,
              'paidDate': b.paidDate?.toIso8601String(),
              'createdAt': b.createdAt.toIso8601String(),
              'updatedAt': b.updatedAt.toIso8601String(),
            },
          )
          .toList(),
      'billPayments': billPayments
          .map(
            (p) => {
              'id': p.id,
              'billId': p.billId,
              'amount': p.amount,
              'currency': p.currency,
              'paidDate': p.paidDate.toIso8601String(),
              'createdAt': p.createdAt.toIso8601String(),
            },
          )
          .toList(),
    };
  }

  /// Replaces all table contents with the data from a backup payload.
  /// The operation is atomic — either all tables are updated or none.
  Future<void> _replaceAll(Map<String, Object?> data) async {
    await _database.transaction(() async {
      // Clear in dependency order (children before parents).
      await (_database.delete(_database.billPayments)).go();
      await (_database.delete(_database.billPayments)).go();
      await (_database.delete(_database.expenses)).go();
      await (_database.delete(_database.bills)).go();
      await (_database.delete(_database.recurringExpenses)).go();
      await (_database.delete(_database.savingsGoals)).go();
      await (_database.delete(_database.categories)).go();
      await (_database.delete(_database.budgets)).go();
      await (_database.delete(_database.settings)).go();

      // Restore budgets
      final budgets = (data['budgets'] as List?) ?? [];
      for (final item in budgets) {
        final map = item as Map;
        await _database
            .into(_database.budgets)
            .insert(
              BudgetsCompanion.insert(
                id: map['id'] as String,
                name: (map['name'] as String?) ?? 'Personal Budget',
                monthlyAmount: (map['monthlyAmount'] as num).toDouble(),
                remainingAmount: (map['remainingAmount'] as num).toDouble(),
                currency: map['currency'] as String,
                startDate: DateTime.parse(map['startDate'] as String),
                endDate: DateTime.parse(map['endDate'] as String),
                isArchived: Value((map['isArchived'] as bool?) ?? false),
                color: Value(map['color'] as String?),
                icon: Value(map['icon'] as String?),
                notes: Value(map['notes'] as String?),
                createdAt: Value(DateTime.parse(map['createdAt'] as String)),
                updatedAt: Value(DateTime.parse(map['updatedAt'] as String)),
              ),
            );
      }

      // Restore categories
      final categories = (data['categories'] as List?) ?? [];
      for (final item in categories) {
        final map = item as Map;
        await _database
            .into(_database.categories)
            .insert(
              CategoriesCompanion.insert(
                id: map['id'] as String,
                name: map['name'] as String,
                icon: map['icon'] as String,
                colorHex: map['colorHex'] as String,
                isSystem: Value((map['isSystem'] as bool?) ?? true),
              ),
            );
      }

      // Restore expenses
      final expenses = (data['expenses'] as List?) ?? [];
      for (final item in expenses) {
        final map = item as Map;
        final tags = (map['tags'] as List?) ?? const [];
        await _database
            .into(_database.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: map['id'] as String,
                budgetId: (map['budgetId'] as String?) ?? '',
                amount: (map['amount'] as num).toDouble(),
                categoryId: map['categoryId'] as String,
                note: Value(map['note'] as String?),
                date: DateTime.parse(map['date'] as String),
                time: Value(DateTime.parse(map['time'] as String)),
                receiptImagePath: Value(map['receiptImagePath'] as String?),
                tags: Value(jsonEncode(tags)),
                createdAt: Value(DateTime.parse(map['createdAt'] as String)),
                updatedAt: Value(DateTime.parse(map['updatedAt'] as String)),
              ),
            );
      }

      // Restore settings
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

      // Restore recurring expenses
      final recurringExpenses = (data['recurringExpenses'] as List?) ?? [];
      for (final item in recurringExpenses) {
        final map = item as Map;
        await _database
            .into(_database.recurringExpenses)
            .insert(
              RecurringExpensesCompanion.insert(
                id: map['id'] as String,
                title: map['title'] as String,
                amount: (map['amount'] as num).toDouble(),
                categoryId: map['categoryId'] as String,
                frequency: map['frequency'] as String,
                nextDueDate: DateTime.parse(map['nextDueDate'] as String),
                isActive: Value((map['isActive'] as bool?) ?? true),
              ),
            );
      }

      // Restore savings goals
      final savingsGoals = (data['savingsGoals'] as List?) ?? [];
      for (final item in savingsGoals) {
        final map = item as Map;
        await _database
            .into(_database.savingsGoals)
            .insert(
              SavingsGoalsCompanion.insert(
                id: map['id'] as String,
                title: map['title'] as String,
                targetAmount: (map['targetAmount'] as num).toDouble(),
                currentAmount: Value(
                  (map['currentAmount'] as num?)?.toDouble() ?? 0.0,
                ),
                targetDate: DateTime.parse(map['targetDate'] as String),
              ),
            );
      }

      // Restore bills
      final bills = (data['bills'] as List?) ?? [];
      for (final item in bills) {
        final map = item as Map;
        await _database
            .into(_database.bills)
            .insert(
              BillsCompanion.insert(
                id: map['id'] as String,
                title: map['title'] as String,
                note: Value(map['note'] as String?),
                amount: (map['amount'] as num).toDouble(),
                currency: map['currency'] as String,
                category: map['category'] as String,
                dueDate: DateTime.parse(map['dueDate'] as String),
                dueTime: Value(
                  map['dueTime'] != null
                      ? DateTime.parse(map['dueTime'] as String)
                      : null,
                ),
                isRecurring: Value((map['isRecurring'] as bool?) ?? false),
                recurrenceType: Value(
                  (map['recurrenceType'] as String?) ?? 'none',
                ),
                recurrenceInterval: Value(
                  (map['recurrenceInterval'] as num?)?.toInt() ?? 1,
                ),
                reminderEnabled: Value(
                  (map['reminderEnabled'] as bool?) ?? false,
                ),
                reminderOffsetDays: Value(
                  (map['reminderOffsetDays'] as num?)?.toInt() ?? 1,
                ),
                isPaid: Value((map['isPaid'] as bool?) ?? false),
                paidDate: Value(
                  map['paidDate'] != null
                      ? DateTime.parse(map['paidDate'] as String)
                      : null,
                ),
                createdAt: Value(DateTime.parse(map['createdAt'] as String)),
                updatedAt: Value(DateTime.parse(map['updatedAt'] as String)),
              ),
            );
      }

      // Restore bill payments
      final billPayments = (data['billPayments'] as List?) ?? [];
      for (final item in billPayments) {
        final map = item as Map;
        await _database
            .into(_database.billPayments)
            .insert(
              BillPaymentsCompanion.insert(
                id: map['id'] as String,
                billId: map['billId'] as String,
                amount: (map['amount'] as num).toDouble(),
                currency: map['currency'] as String,
                paidDate: DateTime.parse(map['paidDate'] as String),
                createdAt: Value(DateTime.parse(map['createdAt'] as String)),
              ),
            );
      }
    });
  }
}
