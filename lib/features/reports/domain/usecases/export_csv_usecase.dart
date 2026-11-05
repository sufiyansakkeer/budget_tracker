import 'dart:io';
import 'dart:ui' show Rect;

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

import '../entities/report_data.dart';
import '../entities/report_failure.dart';
import '../services/report_filter_text.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/files/file_delivery_service.dart';

/// Exports the filtered expenses and summary statistics to a CSV file and
/// opens the share sheet.
class ExportCsvUseCase {
  final FileDeliveryService delivery;

  const ExportCsvUseCase({this.delivery = const FileDeliveryService()});

  /// What happened to the file: a closed share sheet is not an export.
  /// [shareOrigin] anchors the share sheet on iPad; [budgetName] is the
  /// budget the report covers, named in the file.
  Future<ReportResult<FileDeliveryOutcome>> call(
    ReportData data, {
    Rect? shareOrigin,
    String? budgetName,
  }) async {
    try {
      final csv = _buildCsv(data, budgetName);
      final directory = await getTemporaryDirectory();
      final fileName = ReportFileName.of(data.range, 'csv');
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csv);

      return ReportSuccess(
        await delivery.deliver(
          file: file,
          fileName: fileName,
          mimeType: 'text/csv',
          extension: 'csv',
          destination: FileDestination.share,
          shareText: 'Budget Report CSV',
          shareOrigin: shareOrigin,
        ),
      );
    } catch (e) {
      return ReportError(
        ReportFailure(
          type: ReportErrorType.exportFailure,
          message: 'Failed to export CSV: ${e.toString()}',
        ),
      );
    }
  }

  String _buildCsv(ReportData data, String? budgetName) {
    // At the currency's precision: sums and averages of doubles end in
    // ...0000000004 otherwise. Plain numbers, so a spreadsheet can add them;
    // the currency is named once, in its own row and the Amount header.
    final code = data.currency?.toUpperCase();
    final digits = CurrencyFormatter.decimalDigitsFor(code ?? '');
    String money(double amount) => amount.toStringAsFixed(digits);
    final rows = <List<Object?>>[
      [
        'Expense Report - ${data.range.start.toIso8601String().substring(0, 10)} '
            'to ${data.range.end.toIso8601String().substring(0, 10)}',
      ],
      if (ReportFilterText.line(data, money) case final filtered?) [filtered],
      if (budgetName != null && budgetName.isNotEmpty) ['Budget', budgetName],
      if (code != null && code.isNotEmpty) ['Currency', code],
      [],
      ['Total Spending', money(data.overview.totalSpending)],
      ['Total Transactions', data.overview.totalTransactions],
      ['Average Daily Spending', money(data.overview.averageDailySpending)],
      ['Average Transaction', money(data.overview.averageTransactionAmount)],
      ['Highest Expense', money(data.overview.highestExpense)],
      ['Lowest Expense', money(data.overview.lowestExpense)],
      [],
      [
        'Date',
        code == null || code.isEmpty ? 'Amount' : 'Amount ($code)',
        'Category',
        'Note',
        'Tags',
        'Receipt',
      ],
    ];

    final nameById = {for (final c in data.categories) c.id: c.name};

    for (final expense in data.filteredExpenses) {
      rows.add([
        expense.date.toIso8601String().substring(0, 10),
        money(expense.amount),
        nameById[expense.categoryId] ?? expense.categoryId,
        expense.note ?? '',
        expense.tags.join(', '),
        (expense.receiptImagePath != null &&
                expense.receiptImagePath!.isNotEmpty)
            ? 'Yes'
            : 'No',
      ]);
    }

    const converter = ListToCsvConverter();
    return converter.convert(rows);
  }
}
