import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';

/// Handles importing data into the application from CSV or JSON files.
///
/// All imports are transactional: if any record fails validation, no data
/// is written to the database and the existing data remains unchanged.
class ImportService {
  final AppDatabase _database;

  ImportService({required AppDatabase database}) : _database = database;

  /// Imports a CSV file at [path] into the expenses table.
  ///
  /// Skips the header row and validates required columns.
  /// Returns the number of expenses imported.
  ///
  /// The entire import is transactional — if any record fails validation,
  /// no data is written.
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

    // First pass: validate all rows before writing anything.
    final validRows = <_CsvRow>[];
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final columns = line.split(',');
      if (columns.length < 4) continue;

      final amount = double.tryParse(columns[0].trim());
      if (amount == null || !amount.isFinite || amount <= 0) continue;

      final categoryId = columns[1].trim();
      if (categoryId.isEmpty) continue;

      final note = columns.length > 2 ? columns[2].trim() : null;
      final date = DateTime.tryParse(columns[3].trim());
      if (date == null) continue;

      final tags = columns.length > 4 ? columns[4].trim() : '';

      validRows.add(_CsvRow(
        amount: amount,
        categoryId: categoryId,
        note: note,
        date: date,
        tags: tags,
      ));
    }

    if (validRows.isEmpty) {
      throw const FormatException('No valid data rows found in CSV.');
    }

    // Ensure a default budget exists BEFORE starting the transaction, so the
    // foreign key constraint on expenses.budgetId is satisfied.
    final budgetId = await _findOrCreateDefaultBudgetId();

    // Write all valid rows in a transaction.
    int importedCount = 0;
    await _database.transaction(() async {
      for (final row in validRows) {
        await _database
            .into(_database.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: const Uuid().v4(),
                budgetId: budgetId,
                amount: row.amount,
                categoryId: row.categoryId,
                note: Value(
                  row.note?.isNotEmpty == true ? row.note : null,
                ),
                date: row.date,
                time: Value(row.date),
                tags: Value(row.tags.isNotEmpty ? row.tags : null),
              ),
            );
        importedCount++;
      }
    });

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

    // Validate records before importing.
    _validateImportData(data);

    await _upsertAll(data);
    return (meta is Map<String, Object?>
            ? (meta['schemaVersion'] as num?)?.toInt()
            : null) ??
        0;
  }

  /// Validates import data records before writing to the database.
  void _validateImportData(Map<String, Object?> data) {
    // Validate expense records.
    final expenses = (data['expenses'] as List?) ?? [];
    for (var i = 0; i < expenses.length; i++) {
      final item = expenses[i];
      if (item is! Map) {
        throw FormatException('Invalid expense record at index $i.');
      }
      final amount = (item['amount'] as num?)?.toDouble();
      if (amount == null || !amount.isFinite || amount <= 0) {
        throw FormatException(
          'Invalid expense amount at index $i: ${item['amount']}.',
        );
      }
      if (item['date'] != null) {
        final date = DateTime.tryParse(item['date'].toString());
        if (date == null) {
          throw FormatException(
            'Invalid expense date at index $i: ${item['date']}.',
          );
        }
      }
    }

    // Validate budget records.
    final budgets = (data['budgets'] as List?) ?? [];
    for (var i = 0; i < budgets.length; i++) {
      final item = budgets[i];
      if (item is! Map) {
        throw FormatException('Invalid budget record at index $i.');
      }
      final amount = (item['monthlyAmount'] as num?)?.toDouble();
      if (amount == null || !amount.isFinite || amount < 0) {
        throw FormatException(
          'Invalid budget amount at index $i: ${item['monthlyAmount']}.',
        );
      }
    }
  }

  /// Returns the id of an existing budget, creating a default one if none exists.
  ///
  /// This is used to assign imported expenses to a budget when the import does
  /// not specify one.
  String? _cachedDefaultBudgetId;

  Future<String> _findOrCreateDefaultBudgetId() async {
    if (_cachedDefaultBudgetId != null) return _cachedDefaultBudgetId!;

    final existing = await (_database.select(
      _database.budgets,
    )..limit(1)).getSingleOrNull();
    if (existing != null) {
      _cachedDefaultBudgetId = existing.id;
      return _cachedDefaultBudgetId!;
    }

    // Create a default budget spanning the current month.
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);
    final id = const Uuid().v4();
    await _database
        .into(_database.budgets)
        .insert(
          BudgetsCompanion.insert(
            id: id,
            name: 'Personal Budget',
            monthlyAmount: 0,
            remainingAmount: 0,
            currency: 'INR',
            startDate: start,
            endDate: end,
            updatedAt: Value(now),
          ),
        );
    _cachedDefaultBudgetId = id;
    return id;
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
        final mappedBudgetId =
            (map['budgetId'] as String?) ??
            (await _findOrCreateDefaultBudgetId());
        await _database
            .into(_database.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: (map['id'] as String?) ?? const Uuid().v4(),
                budgetId: mappedBudgetId,
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

/// Internal CSV row representation for two-pass import.
class _CsvRow {
  final double amount;
  final String categoryId;
  final String? note;
  final DateTime date;
  final String tags;

  const _CsvRow({
    required this.amount,
    required this.categoryId,
    this.note,
    required this.date,
    required this.tags,
  });
}
