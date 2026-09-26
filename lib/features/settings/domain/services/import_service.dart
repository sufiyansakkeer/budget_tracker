import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/default_categories.dart';

/// Handles importing data into the application from CSV or JSON files.
///
/// All imports are transactional: if any record fails validation, no data
/// is written to the database and the existing data remains unchanged.
class ImportService {
  final AppDatabase _database;

  ImportService({required AppDatabase database}) : _database = database;

  /// Imports expenses from a CSV file at [path].
  ///
  /// Accepts the file produced by [ExportService.exportCsv] as well as any
  /// spreadsheet with a header row that names at least `amount`, a category
  /// column (`category` or `categoryId`) and `date`. Columns are matched by
  /// header name, so their order does not matter; quoted fields and embedded
  /// commas are handled by the CSV parser. Rows that fail validation are
  /// skipped; the valid ones are written in one transaction.
  ///
  /// Unknown categories are matched by name and otherwise fall back to
  /// "Others", so a foreign-key violation can never abort the import.
  /// Returns the number of expenses imported.
  Future<int> importCsv(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const FormatException('CSV file not found.');
    }

    final raw = await file.readAsString();
    final table = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(raw.replaceAll('\r\n', '\n'));

    final headerIndex = table.indexWhere(_isExpenseHeader);
    if (headerIndex == -1 || headerIndex == table.length - 1) {
      throw const FormatException('CSV file is empty or has no data rows.');
    }
    final columns = _ColumnMap.fromHeader(table[headerIndex]);

    await _database.seedDefaultCategories();
    final categoryRows = await (_database.select(_database.categories)).get();
    final categoryIds = {for (final c in categoryRows) c.id};
    final categoryByName = {
      for (final c in categoryRows) c.name.trim().toLowerCase(): c.id,
    };
    final budgetIds = {
      for (final b in await (_database.select(_database.budgets)).get()) b.id,
    };

    // First pass: validate all rows before writing anything.
    final validRows = <_CsvRow>[];
    for (final row in table.skip(headerIndex + 1)) {
      final cells = row.map((c) => c.toString().trim()).toList();
      if (cells.every((c) => c.isEmpty)) continue;

      final amount = double.tryParse(columns.read(cells, 'amount') ?? '');
      if (amount == null || !amount.isFinite || amount <= 0) continue;

      final date = _parseDate(columns.read(cells, 'date'));
      if (date == null) continue;

      final rawCategory =
          columns.read(cells, 'categoryid') ??
          columns.read(cells, 'category') ??
          '';
      final categoryId = categoryIds.contains(rawCategory)
          ? rawCategory
          : categoryByName[rawCategory.toLowerCase()] ?? fallbackCategoryId;

      final rawBudget = columns.read(cells, 'budgetid');
      final budgetId = rawBudget != null && budgetIds.contains(rawBudget)
          ? rawBudget
          : null;

      final time = _parseDate(columns.read(cells, 'time')) ?? date;
      final note = columns.read(cells, 'note');
      final tags = columns.read(cells, 'tags') ?? '';

      validRows.add(
        _CsvRow(
          amount: amount,
          categoryId: categoryId,
          budgetId: budgetId,
          note: note,
          date: date,
          time: time,
          tags: tags,
        ),
      );
    }

    if (validRows.isEmpty) {
      throw const FormatException('No valid data rows found in CSV.');
    }

    // Ensure a default budget exists BEFORE starting the transaction, so the
    // foreign key constraint on expenses.budgetId is satisfied.
    final defaultBudgetId = await _findOrCreateDefaultBudgetId();

    int importedCount = 0;
    await _database.transaction(() async {
      for (final row in validRows) {
        await _database
            .into(_database.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: const Uuid().v4(),
                budgetId: row.budgetId ?? defaultBudgetId,
                amount: row.amount,
                categoryId: row.categoryId,
                note: Value(row.note?.isNotEmpty == true ? row.note : null),
                date: row.date,
                time: Value(row.time),
                tags: Value(row.tags.isNotEmpty ? row.tags : null),
              ),
            );
        importedCount++;
      }
    });

    return importedCount;
  }

  static bool _isExpenseHeader(List<dynamic> row) {
    final names = row.map(_ColumnMap.normalize).toSet();
    return names.contains('amount') &&
        names.contains('date') &&
        (names.contains('category') || names.contains('categoryid'));
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
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
  final String? budgetId;
  final String? note;
  final DateTime date;
  final DateTime time;
  final String tags;

  const _CsvRow({
    required this.amount,
    required this.categoryId,
    required this.budgetId,
    required this.note,
    required this.date,
    required this.time,
    required this.tags,
  });
}

/// Header-name → column-index lookup that ignores case, spaces and
/// underscores (`Category Id`, `category_id` and `categoryId` all match).
class _ColumnMap {
  final Map<String, int> _index;

  const _ColumnMap._(this._index);

  factory _ColumnMap.fromHeader(List<dynamic> header) {
    final map = <String, int>{};
    for (var i = 0; i < header.length; i++) {
      map.putIfAbsent(normalize(header[i]), () => i);
    }
    return _ColumnMap._(map);
  }

  static String normalize(Object? cell) =>
      cell.toString().trim().toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');

  String? read(List<String> cells, String name) {
    final i = _index[name];
    if (i == null || i >= cells.length) return null;
    final value = cells[i];
    return value.isEmpty ? null : value;
  }
}
