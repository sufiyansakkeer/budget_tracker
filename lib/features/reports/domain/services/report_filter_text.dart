import '../entities/report_data.dart';
import '../entities/report_period.dart';

/// A report's filter in words, for the exports: a filtered total must not
/// pass for the whole budget's (UX-053).
abstract final class ReportFilterText {
  /// "Filtered: Food · Min 10 · #work · Has receipt", with amounts written
  /// by [money]; null when no filter is on. Reports take their dates from
  /// the period, which the export already states.
  static String? line(ReportData data, String Function(double amount) money) {
    final filter = data.filter;
    final categoryId = filter.categoryId;
    final parts = [
      if (categoryId != null)
        data.categories
                .where((c) => c.id == categoryId)
                .map((c) => c.name)
                .firstOrNull ??
            categoryId,
      if (filter.minAmount != null) 'Min ${money(filter.minAmount!)}',
      if (filter.maxAmount != null) 'Max ${money(filter.maxAmount!)}',
      for (final tag in filter.tags) '#$tag',
      if (filter.receiptOnly) 'Has receipt',
    ];
    return parts.isEmpty ? null : 'Filtered: ${parts.join(' · ')}';
  }
}

/// The name an exported report is shared under: what it covers, readable
/// in a chat or a Downloads folder ("monivo-report-2026-09-01-to-2026-09-30
/// .csv"), not a millisecond timestamp (UX-089).
abstract final class ReportFileName {
  static String of(ReportRange range, String extension) {
    String day(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final start = day(range.start);
    final end = day(range.end);
    final dates = start == end ? start : '$start-to-$end';
    return 'monivo-report-$dates.$extension';
  }
}
