import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/database/app_database.dart';

/// Represents a generated export file.
class ExportResult {
  final String filePath;
  final String message;

  const ExportResult({required this.filePath, required this.message});
}

/// Exports application data to CSV or JSON files for sharing.
class ExportService {
  final AppDatabase _database;

  ExportService({required AppDatabase database}) : _database = database;

  /// CSV header written by [collectCsvRows]. [ImportService.importCsv] reads
  /// the same names, so an export can always be re-imported.
  static const List<String> csvHeader = [
    'id',
    'date',
    'time',
    'amount',
    'currency',
    'category',
    'categoryId',
    'budget',
    'budgetId',
    'note',
    'tags',
    'receipt',
  ];

  /// One expense per row with its category and budget resolved to names, so
  /// the file opens cleanly in a spreadsheet. Pure (no platform channels) so
  /// it can be unit tested.
  Future<List<List<Object?>>> collectCsvRows() async {
    final expenses = await (_database.select(
      _database.expenses,
    )..orderBy([(e) => OrderingTerm.desc(e.date)])).get();
    final categories = await (_database.select(_database.categories)).get();
    final budgets = await (_database.select(_database.budgets)).get();
    final categoryById = {for (final c in categories) c.id: c};
    final budgetById = {for (final b in budgets) b.id: b};

    return <List<Object?>>[
      csvHeader,
      for (final e in expenses)
        [
          e.id,
          e.date.toIso8601String(),
          e.time.toIso8601String(),
          e.amount,
          budgetById[e.budgetId]?.currency ?? '',
          categoryById[e.categoryId]?.name ?? e.categoryId,
          e.categoryId,
          budgetById[e.budgetId]?.name ?? '',
          e.budgetId,
          e.note ?? '',
          e.tags ?? '',
          e.receiptImagePath ?? '',
        ],
    ];
  }

  /// Collects the complete application data as a JSON-serializable map.
  /// This stays pure so it can be unit tested.
  Future<Map<String, Object?>> collectJsonData() async {
    final expenses = await (_database.select(_database.expenses)).get();
    final categories = await (_database.select(_database.categories)).get();
    final budgets = await (_database.select(_database.budgets)).get();
    final settingsRows = await (_database.select(_database.settings)).get();

    return <String, Object?>{
      'schemaVersion': _database.schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
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
      'settings': {for (final s in settingsRows) s.key: s.value},
    };
  }

  /// Exports expenses + categories + budget to a CSV file and opens the share
  /// sheet.
  Future<ExportResult> exportCsv() async {
    final rows = await collectCsvRows();
    const converter = ListToCsvConverter();
    final csv = converter.convert(rows);

    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/budget_export_$timestamp.csv');
    await file.writeAsString(csv);

    await Share.shareXFiles([
      XFile(file.path, mimeType: 'text/csv'),
    ], text: 'Monivo Export');

    return ExportResult(filePath: file.path, message: 'CSV exported.');
  }

  /// Exports the complete application data as a JSON backup and opens the
  /// share sheet.
  Future<ExportResult> exportJson() async {
    final data = await collectJsonData();

    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/budget_backup_$timestamp.json');

    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(data));

    await Share.shareXFiles([
      XFile(file.path, mimeType: 'application/json'),
    ], text: 'Monivo Backup');

    return ExportResult(filePath: file.path, message: 'JSON backup exported.');
  }
}
