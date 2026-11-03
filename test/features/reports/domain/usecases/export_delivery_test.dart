import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/files/file_delivery_service.dart';
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/entities/expense_history_filter.dart';
import 'package:monivo/features/reports/domain/entities/report_data.dart';
import 'package:monivo/features/reports/domain/entities/report_failure.dart';
import 'package:monivo/features/reports/domain/entities/report_period.dart';
import 'package:monivo/features/reports/domain/services/analytics_service.dart';
import 'package:monivo/features/reports/domain/usecases/export_csv_usecase.dart';
import 'package:monivo/features/reports/domain/usecases/export_pdf_usecase.dart';

/// A report export said "ready to share" even when the share sheet was
/// closed without choosing an app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('monivo_export_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => temp.path,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    temp.deleteSync(recursive: true);
  });

  ReportData report() => const AnalyticsService().buildReportData(
    range: ReportRange(
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 9, 30),
      period: ReportPeriod.lastMonth,
    ),
    filteredExpenses: [
      for (final (id, amount) in [('e1', 0.1), ('e2', 0.2)])
        ExpenseEntity(
          id: id,
          budgetId: 'b1',
          amount: amount,
          categoryId: 'food',
          date: DateTime(2026, 9, 10),
          time: DateTime(2026, 9, 10, 12),
          createdAt: DateTime(2026, 9, 10, 12),
          updatedAt: DateTime(2026, 9, 10, 12),
        ),
    ],
    categories: defaultCategories,
    filter: const ExpenseHistoryFilter(),
    currency: 'OMR',
  );

  for (final outcome in FileDeliveryOutcome.values) {
    test('the CSV report passes $outcome through', () async {
      final delivery = _Delivery(outcome);
      final result = await ExportCsvUseCase(delivery: delivery)(report());

      expect((result as ReportSuccess<FileDeliveryOutcome>).data, outcome);
      expect(delivery.destination, FileDestination.share);
      expect(delivery.extension, 'csv');
    });
  }

  test('the PDF report passes a dismissed share sheet through', () async {
    final delivery = _Delivery(FileDeliveryOutcome.cancelled);
    final result = await ExportPdfUseCase(delivery: delivery)(report());

    expect(
      (result as ReportSuccess<FileDeliveryOutcome>).data,
      FileDeliveryOutcome.cancelled,
    );
    expect(delivery.extension, 'pdf');
  });

  test('CSV amounts are written at the currency precision', () async {
    final delivery = _Delivery(FileDeliveryOutcome.shared);
    await ExportCsvUseCase(delivery: delivery)(report());

    final csv = await delivery.file!.readAsString();
    // 0.1 + 0.2 is 0.30000000000000004 in doubles.
    expect(csv, contains('Total Spending,0.300'));
    expect(csv, contains('2026-09-10,0.100,'));
    expect(csv, isNot(contains('0000000')));
  });
}

class _Delivery extends FileDeliveryService {
  final FileDeliveryOutcome outcome;
  File? file;
  String? extension;
  FileDestination? destination;

  _Delivery(this.outcome);

  @override
  Future<FileDeliveryOutcome> deliver({
    required File file,
    required String fileName,
    required String mimeType,
    required String extension,
    required FileDestination destination,
    String? shareText,
  }) async {
    this.file = file;
    this.extension = extension;
    this.destination = destination;
    return outcome;
  }
}
