import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../entities/report_data.dart';
import '../entities/report_failure.dart';

/// Exports the filtered expenses and summary statistics to a CSV file and
/// opens the share sheet.
class ExportCsvUseCase {
  const ExportCsvUseCase();

  Future<ReportResult<String>> call(ReportData data) async {
    try {
      final csv = _buildCsv(data);
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/budget_report_$timestamp.csv');
      await file.writeAsString(csv);

      await Share.shareXFiles([
        XFile(file.path, mimeType: 'text/csv'),
      ], text: 'Budget Report CSV');
      return ReportSuccess('CSV report exported.');
    } catch (e) {
      return ReportError(
        ReportFailure(
          type: ReportErrorType.exportFailure,
          message: 'Failed to export CSV: ${e.toString()}',
        ),
      );
    }
  }

  String _buildCsv(ReportData data) {
    final rows = <List<Object?>>[
      [
        'Expense Report - ${data.range.start.toIso8601String().substring(0, 10)} '
            'to ${data.range.end.toIso8601String().substring(0, 10)}',
      ],
      [],
      ['Total Spending', data.overview.totalSpending],
      ['Total Transactions', data.overview.totalTransactions],
      ['Average Daily Spending', data.overview.averageDailySpending],
      ['Average Transaction', data.overview.averageTransactionAmount],
      ['Highest Expense', data.overview.highestExpense],
      ['Lowest Expense', data.overview.lowestExpense],
      [],
      ['Date', 'Amount', 'Category', 'Note', 'Tags', 'Receipt'],
    ];

    final nameById = {for (final c in data.categories) c.id: c.name};

    for (final expense in data.filteredExpenses) {
      rows.add([
        expense.date.toIso8601String().substring(0, 10),
        expense.amount,
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
