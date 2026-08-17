import 'dart:convert';
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

/// Handles full database backup and restore to/from a local JSON file.
///
/// Everything remains local — no cloud services.
class BackupService {
  static const String _appVersion = '1.0.0';

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

  /// Restores the database from a backup file at [path].
  ///
  /// Validates the payload and schema before applying. Returns the metadata
  /// that was restored.
  Future<BackupMetadata> restore(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const FormatException('Backup file not found.');
    }

    final raw = await file.readAsString();
    final Map<String, Object?> payload;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Invalid backup format.');
      }
      payload = decoded;
    } catch (e) {
      throw FormatException('Corrupted backup file: $e');
    }

    if (payload['type'] != 'monivo_backup') {
      throw const FormatException('Not a valid Monivo backup.');
    }

    final meta = payload['metadata'];
    if (meta is! Map<String, Object?>) {
      throw const FormatException('Backup metadata missing.');
    }

    final schemaVersion = (meta['schemaVersion'] as num?)?.toInt() ?? 0;
    if (schemaVersion > _database.schemaVersion) {
      throw FormatException(
        'Backup schema v$schemaVersion is newer than supported '
        'v${_database.schemaVersion}.',
      );
    }

    final data = payload['data'];
    if (data is! Map<String, Object?>) {
      throw const FormatException('Backup data missing.');
    }

    await _replaceAll(data);

    return BackupMetadata(
      createdAt:
          DateTime.tryParse(meta['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      appVersion: meta['appVersion']?.toString() ?? 'unknown',
      schemaVersion: schemaVersion,
    );
  }

  Future<Map<String, Object?>> _collectData() async {
    final expenses = await (_database.select(_database.expenses)).get();
    final categories = await (_database.select(_database.categories)).get();
    final budgets = await (_database.select(_database.budgets)).get();
    final settings = await (_database.select(_database.settings)).get();

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
    };
  }

  /// Replaces all table contents with the data from a backup payload.
  Future<void> _replaceAll(Map<String, Object?> data) async {
    await _database.transaction(() async {
      await (_database.delete(_database.expenses)).go();
      await (_database.delete(_database.categories)).go();
      await (_database.delete(_database.budgets)).go();
      await (_database.delete(_database.settings)).go();

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
    });
  }
}
