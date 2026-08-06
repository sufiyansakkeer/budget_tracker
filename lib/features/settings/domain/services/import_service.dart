import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';

/// Handles importing data into the application from CSV or JSON files.
class ImportService {
  final AppDatabase _database;

  ImportService({required AppDatabase database}) : _database = database;

  /// Imports a CSV file at [path] into the expenses table.
  ///
  /// Skips the header row and validates required columns.
  /// Returns the number of expenses imported.
  Future<int> importCsv(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const FormatException('CSV file not found.');
    }

    final raw = await file.readAsString();
    final lines = raw
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.length < 2) {
      throw const FormatException('CSV file is empty or has no data rows.');
    }

    // Expected header: amount,categoryId,note,date,tags
    int importedCount = 0;

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final columns = line.split(',');
      if (columns.length < 4) continue;

      final amount = double.tryParse(columns[0].trim());
      if (amount == null || amount <= 0) continue;

      final categoryId = columns[1].trim();
      final note = columns.length > 2 ? columns[2].trim() : null;
      final date = DateTime.tryParse(columns[3].trim());
      if (date == null) continue;

      final tags = columns.length > 4 ? columns[4].trim() : '';

      await _database
          .into(_database.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: const Uuid().v4(),
              amount: amount,
              categoryId: categoryId,
              note: Value(note?.isNotEmpty == true ? note : null),
              date: date,
              time: Value(date),
              tags: Value(tags.isNotEmpty ? tags : null),
            ),
          );
      importedCount++;
    }

    return importedCount;
  }

  /// Imports a JSON backup file at [path].
  ///
  /// Validates structure and schema version before applying.
  /// Returns the schema version found in the file.
  Future<int> importJson(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const FormatException('JSON file not found.');
    }

    final raw = await file.readAsString();
    final Map<String, Object?> payload;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Invalid JSON format.');
      }
      payload = decoded;
    } catch (e) {
      throw FormatException('Corrupted JSON file: $e');
    }

    // Support both backup format and data-only format.
    final data = payload['data'] ?? payload;
    if (data is! Map<String, Object?>) {
      throw const FormatException('Import data missing.');
    }

    // Check schema version if available.
    final meta = payload['metadata'];
    if (meta is Map<String, Object?>) {
      final schemaVersion = (meta['schemaVersion'] as num?)?.toInt() ?? 0;
      if (schemaVersion > _database.schemaVersion) {
        throw FormatException(
          'Schema v$schemaVersion is newer than supported '
          'v${_database.schemaVersion}.',
        );
      }
    }

    await _upsertAll(data);
    return (meta is Map<String, Object?>
            ? (meta['schemaVersion'] as num?)?.toInt()
            : null) ??
        0;
  }

  /// Inserts or updates data from an import payload, avoiding full replacement
  /// so the user can selectively import.
  Future<void> _upsertAll(Map<String, Object?> data) async {
    await _database.transaction(() async {
      final budgets = (data['budgets'] as List?) ?? [];
      for (final item in budgets) {
        final map = item as Map;
        await _database
            .into(_database.budgets)
            .insert(
              BudgetsCompanion.insert(
                id: map['id'] as String,
                monthlyAmount: (map['monthlyAmount'] as num).toDouble(),
                remainingAmount: (map['remainingAmount'] as num).toDouble(),
                currency: map['currency'] as String,
                month: (map['month'] as num).toInt(),
                year: (map['year'] as num).toInt(),
                createdAt: Value(DateTime.parse(map['createdAt'] as String)),
              ),
              mode: InsertMode.insertOrReplace,
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
              mode: InsertMode.insertOrReplace,
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
                id: (map['id'] as String?) ?? const Uuid().v4(),
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
              mode: InsertMode.insertOrReplace,
            );
      }
    });
  }
}
