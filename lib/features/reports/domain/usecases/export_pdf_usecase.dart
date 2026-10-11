import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../../../core/currency/currency_formatter.dart';

import '../entities/report_data.dart';
import '../entities/report_failure.dart';
import '../../../../core/platform/system_ui_session.dart';

/// The fonts a report PDF is drawn with: the app's own Manrope, and the
/// bundled Omani Rial sign as a fallback.
///
/// The PDF used the built-in Helvetica, which only has Latin-1 glyphs, so
/// ₹, €, the Omani Rial sign, "—" and "•" were drawn as crossed boxes.
class PdfFonts {
  final ByteData regular;
  final ByteData bold;
  final ByteData omaniRial;

  const PdfFonts({
    required this.regular,
    required this.bold,
    required this.omaniRial,
  });

  static Future<PdfFonts> load() async => PdfFonts(
    regular: await rootBundle.load('assets/fonts/manrope/Manrope-Regular.ttf'),
    bold: await rootBundle.load('assets/fonts/manrope/Manrope-Bold.ttf'),
    omaniRial: await rootBundle.load(
      'assets/fonts/omani_rial/MonivoOmaniRial-Medium.ttf',
    ),
  );

  /// Whether the regular font or the Omani Rial fallback has a glyph for
  /// every character of [text]. Checked on a scratch document, so nothing
  /// is added to the report.
  bool Function(String text) coverage() {
    final probe = PdfDocument();
    final fonts = [PdfTtfFont(probe, regular), PdfTtfFont(probe, omaniRial)];
    return (text) => text.runes.every(
      (rune) => fonts.any((font) => font.isRuneSupported(rune)),
    );
  }
}

/// Generates a professional PDF report (overview, category summary, trends,
/// insights) from [ReportData] and opens the share sheet.
class ExportPdfUseCase {
  const ExportPdfUseCase();

  Future<ReportResult<String>> call(ReportData data) async {
    try {
      final document = buildDocument(data, await PdfFonts.load());
      final bytes = await document.save();
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/budget_report_$timestamp.pdf');
      await file.writeAsBytes(bytes);

      await SystemUiSession.run(
        () => Share.shareXFiles([
          XFile(file.path, mimeType: 'application/pdf'),
        ], text: 'Budget Report PDF'),
      );
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

  /// The report as a PDF document, drawn with [fonts].
  @visibleForTesting
  pw.Document buildDocument(ReportData data, PdfFonts fonts) {
    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(fonts.regular),
      bold: pw.Font.ttf(fonts.bold),
      fontFallback: [pw.Font.ttf(fonts.omaniRial)],
    );
    final document = pw.Document(theme: theme);
    final drawable = fonts.coverage();
    // The report's own currency, the one every on-screen figure uses. It
    // used to come from a budget attached only for the current month, so any
    // other period printed ₹ whatever the budget's currency.
    final currency = data.currency;
    String money(double v) => pdfMoney(v, currency, drawable: drawable);

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
              child: pw.Text('• $insight'),
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

  /// [amount] as the PDF shows it: the currency's symbol at its real
  /// precision (OMR keeps its fils, a whole amount shows no decimals), or the
  /// ISO code when the PDF's fonts cannot draw the symbol (the dirham's
  /// Arabic letters). Bidi marks the app adds for right-to-left symbols are
  /// dropped; the PDF has no glyph for them. No currency: a plain number.
  @visibleForTesting
  static String pdfMoney(
    double amount,
    String? currency, {
    required bool Function(String text) drawable,
  }) {
    if (currency == null || currency.isEmpty) {
      return NumberFormat.decimalPatternDigits(
        decimalDigits: amount == amount.roundToDouble() ? 0 : 2,
      ).format(amount);
    }
    final digits = CurrencyFormatter.exactDisplayDigits(amount, code: currency);
    final symbol = CurrencyFormatter.format(
      amount,
      code: currency,
      decimalDigits: digits,
    ).replaceAll(_bidiMarks, '');
    if (drawable(symbol)) return symbol;
    return NumberFormat.currency(
      symbol: '${currency.toUpperCase()}\u00A0',
      decimalDigits: digits,
    ).format(amount);
  }

  static final RegExp _bidiMarks = RegExp(
    '[\u200E\u200F\u202A-\u202E\u2066-\u2069]',
  );

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
