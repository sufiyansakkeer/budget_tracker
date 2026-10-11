import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:monivo/features/expenses/domain/entities/expense_category.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/expenses/domain/entities/expense_history_filter.dart';
import 'package:monivo/features/reports/domain/entities/report_data.dart';
import 'package:monivo/features/reports/domain/entities/report_period.dart';
import 'package:monivo/features/reports/domain/services/analytics_service.dart';
import 'package:monivo/features/reports/domain/usecases/export_pdf_usecase.dart';

/// UX-010: the PDF printed ₹ for any period outside the current month
/// (currency came from a budget attached only then) and drew ₹, €, the
/// Omani Rial sign, "—" and "•" as crossed boxes (built-in Helvetica has
/// Latin-1 glyphs only).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PdfFonts fonts;
  late bool Function(String) drawable;

  setUpAll(() async {
    fonts = await PdfFonts.load();
    drawable = fonts.coverage();
  });

  String money(double amount, String? currency) =>
      ExportPdfUseCase.pdfMoney(amount, currency, drawable: drawable);

  test('the bundled fonts draw the symbols the PDF needs', () {
    for (final text in ['₹', '€', r'$', '£', '¥', '—', '•', '⃄']) {
      expect(drawable(text), isTrue, reason: text);
    }
  });

  test('amounts use the report currency at its real precision', () {
    expect(money(1250, 'INR'), '₹1,250');
    expect(money(1250.5, 'INR'), '₹1,250.50');
    expect(money(12.35, 'OMR'), '⃄ 12.350', reason: 'fils kept');
    expect(money(12, 'OMR'), '⃄ 12');
    expect(money(9.99, 'USD'), r'$9.99');
    expect(money(1200, 'JPY'), '¥1,200');
  });

  test('a symbol the fonts cannot draw is written as its ISO code', () {
    // The dirham's Arabic letters have no glyph in the bundled fonts.
    expect(drawable('د.إ'), isFalse);
    expect(money(10.5, 'AED'), 'AED 10.50');
    expect(money(10.5, 'AED'), isNot(contains('‎')));
  });

  test('without a currency, a plain number', () {
    expect(money(1250, null), '1,250');
    expect(money(1250.5, ''), '1,250.50');
  });

  ReportData report(String currency) {
    final range = ReportRange(
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 9, 30),
      period: ReportPeriod.lastMonth,
    );
    return const AnalyticsService().buildReportData(
      range: range,
      filteredExpenses: [
        ExpenseEntity(
          id: 'e1',
          budgetId: 'b1',
          amount: 12.35,
          categoryId: 'food',
          date: DateTime(2026, 9, 10),
          time: DateTime(2026, 9, 10, 12),
          createdAt: DateTime(2026, 9, 10, 12),
          updatedAt: DateTime(2026, 9, 10, 12),
        ),
      ],
      categories: defaultCategories,
      filter: const ExpenseHistoryFilter(),
      // Last month: no current-month budget is attached, as in the app.
      currency: currency,
    );
  }

  for (final currency in ['OMR', 'AED', 'INR']) {
    test('a $currency report for last month builds with the bundled fonts, '
        'not Helvetica', () async {
      final data = report(currency);
      expect(data.currentBudget, isNull);

      final document = const ExportPdfUseCase().buildDocument(data, fonts);

      final style = document.theme!.defaultTextStyle;
      expect(style.font, isA<pw.TtfFont>(), reason: 'not built-in Helvetica');
      expect(style.fontFallback.single, isA<pw.TtfFont>());
      final bytes = await document.save();
      expect(latin1.decode(bytes.sublist(0, 8)), startsWith('%PDF'));
    });
  }
}
