import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../entities/report_data.dart';
import '../entities/report_failure.dart';

/// Generates a professional PDF report (overview, category summary, trends,
/// insights) from [ReportData] and opens the share sheet.
class ExportPdfUseCase {
  const ExportPdfUseCase();

  Future<ReportResult<String>> call(ReportData data) async {
    try {
      final document = _buildDocument(data);
      final bytes = await document.save();
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/budget_report_$timestamp.pdf');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([
        XFile(file.path, mimeType: 'application/pdf'),
      ], text: 'Budget Report PDF');
      return ReportSuccess('PDF report exported.');
    } catch (e) {
      return ReportError(
        ReportFailure(
          type: ReportErrorType.exportFailure,
          message: 'Failed to export PDF: ${e.toString()}',
        ),
      );
    }
  }

  pw.Document _buildDocument(ReportData data) {
    final currency = data.currentBudget?.currency ?? '₹';
    final money = (double v) =>
        NumberFormat.currency(symbol: currency, decimalDigits: 0).format(v);

    final theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    );

    final document = pw.Document(theme: theme);
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Expense Report',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.teal700,
              ),
            ),
          ),
          pw.Text(
            '${_fmtDate(data.range.start)} — ${_fmtDate(data.range.end)}',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),

          pw.Header(level: 1, text: 'Overview'),
          pw.TableHelper.fromTextArray(
            headers: const ['Metric', 'Value'],
            data: [
              ['Total Spending', money(data.overview.totalSpending)],
              ['Total Transactions', '${data.overview.totalTransactions}'],
              [
                'Average Daily Spending',
                money(data.overview.averageDailySpending),
              ],
              [
                'Average Transaction',
                money(data.overview.averageTransactionAmount),
              ],
              ['Highest Expense', money(data.overview.highestExpense)],
              ['Lowest Expense', money(data.overview.lowestExpense)],
            ],
          ),
          pw.SizedBox(height: 16),

          pw.Header(level: 1, text: 'Category Summary'),
          if (data.categoryAnalytics.isEmpty)
            pw.Text('No category data.')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Category', 'Amount', 'Txns', '% of Total'],
              data: [
                for (final c in data.categoryAnalytics)
                  [
                    c.categoryName,
                    money(c.totalAmount),
                    '${c.transactionCount}',
                    '${c.percentageOfTotal.toStringAsFixed(1)}%',
                  ],
              ],
            ),
          pw.SizedBox(height: 16),

          pw.Header(level: 1, text: 'Spending Trends'),
          pw.Text('Daily average: ${money(data.trend.dailyAverage)}'),
          pw.Text('Weekly average: ${money(data.trend.weeklyAverage)}'),
          pw.Text('Monthly average: ${money(data.trend.monthlyAverage)}'),
          pw.Text(
            'Growth vs previous period: '
            '${(data.trend.growthRate * 100).toStringAsFixed(1)}%',
          ),
          pw.Text(
            'Consistency score: '
            '${(data.trend.consistencyScore * 100).toStringAsFixed(0)}%',
          ),
          pw.SizedBox(height: 16),

          pw.Header(level: 1, text: 'Insights'),
          for (final insight in _insights(data))
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text('• ${insight}'),
            ),
        ],
      ),
    );
    return document;
  }

  List<String> _insights(ReportData data) {
    final insights = <String>[];
    if (!data.isEmpty) {
      if (data.categoryAnalytics.isNotEmpty) {
        final top = data.categoryAnalytics.first;
        insights.add(
          '${top.categoryName} accounts for '
          '${top.percentageOfTotal.toStringAsFixed(0)}% of your spending.',
        );
      }
      final change = data.trend.growthRate;
      if (change.abs() >= 0.02) {
        insights.add(
          change < 0
              ? 'You\'re spending ${(change.abs() * 100).toStringAsFixed(0)}% '
                    'less than the previous period.'
              : 'You\'re spending ${(change.abs() * 100).toStringAsFixed(0)}% '
                    'more than the previous period.',
        );
      }
      if (data.trend.isImproving) {
        insights.add('Your spending trend has improved.');
      }
    }
    if (insights.isEmpty) {
      insights.add('Add expenses to see personalized insights.');
    }
    return insights;
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
