import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:csv/csv.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:path_provider/path_provider.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/files/file_delivery_service.dart';
import 'data_codec.dart';

/// Represents a generated export file.
class ExportResult {
  final String filePath;
  final String message;

  const ExportResult({required this.filePath, required this.message});
}

/// Exports application data to CSV or JSON files for sharing.
class ExportService {
  final AppDatabase _database;
  final FileDeliveryService _delivery;

  ExportService({
    required AppDatabase database,
    FileDeliveryService delivery = const FileDeliveryService(),
  }) : _database = database,
       _delivery = delivery;

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
      // Marks an export, so Restore can tell it from a backup and point to
      // Import instead.
      'type': 'monivo_export',
      'schemaVersion': _database.schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'budgets': budgets.map(DataCodec.encodeBudget).toList(),
      'categories': categories.map(DataCodec.encodeCategory).toList(),
      'expenses': expenses.map(DataCodec.encodeExpense).toList(),
      'settings': {for (final s in settingsRows) s.key: s.value},
    };
  }

  /// Exports expenses + categories + budget to a CSV file and opens the share
  /// sheet, anchored at [shareOrigin] on iPad.
  Future<ExportResult> exportCsv({Rect? shareOrigin}) async {
    final rows = await collectCsvRows();
    const converter = ListToCsvConverter();
    final csv = converter.convert(rows);

    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'budget_export_$timestamp.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csv);

    return _share(
      file,
      fileName,
      'text/csv',
      'csv',
      done: 'CSV exported.',
      shareOrigin: shareOrigin,
    );
  }

  /// Exports budgets, categories, expenses and settings as a data file and
  /// opens the share sheet.
  ///
  /// This is an export, not a backup: it leaves out bills and is meant for
  /// other apps or Import. It used to be named and shared as "Monivo
  /// Backup", which Restore then rejected as damaged.
  Future<ExportResult> exportJson({Rect? shareOrigin}) async {
    final data = await collectJsonData();

    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'monivo_export_$timestamp.json';
    final file = File('${directory.path}/$fileName');

    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(data));

    return _share(
      file,
      fileName,
      'application/json',
      'json',
      done: 'Data file exported.',
      shareOrigin: shareOrigin,
    );
  }

  /// Opens the share sheet for [file]. A closed sheet is not an export.
  Future<ExportResult> _share(
    File file,
    String fileName,
    String mimeType,
    String extension, {
    required String done,
    Rect? shareOrigin,
  }) async {
    final outcome = await _delivery.deliver(
      file: file,
      fileName: fileName,
      mimeType: mimeType,
      extension: extension,
      destination: FileDestination.share,
      shareText: 'Monivo export',
      shareOrigin: shareOrigin,
    );
    return ExportResult(
      filePath: file.path,
      message: switch (outcome) {
        FileDeliveryOutcome.shared || FileDeliveryOutcome.saved => done,
        FileDeliveryOutcome.handedOff => 'Export sent to the share sheet.',
        FileDeliveryOutcome.cancelled => 'Export cancelled.',
      },
    );
  }
}
