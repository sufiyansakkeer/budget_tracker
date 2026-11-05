import '../entities/report_data.dart';

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
