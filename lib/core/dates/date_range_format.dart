import 'package:intl/intl.dart';

/// Formats a date range like "1 Aug – 31 Aug 2026".
String formatDateRange(DateTime start, DateTime end) {
  final sameYear = start.year == end.year;
  final startFmt = sameYear ? DateFormat('d MMM') : DateFormat('d MMM yyyy');
  final endFmt = DateFormat('d MMM yyyy');
  return '${startFmt.format(start)} – ${endFmt.format(end)}';
}

/// Formats a short date range like "1 Aug – 31 Aug" (no year).
String formatShortDateRange(DateTime start, DateTime end) {
  final fmt = DateFormat('d MMM');
  return '${fmt.format(start)} – ${fmt.format(end)}';
}
