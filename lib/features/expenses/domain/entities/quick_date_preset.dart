import 'expense_history_filter.dart';

/// Named date ranges offered by the expense filters.
///
/// Pure Dart: [range] takes an optional [now] so the boundaries are
/// deterministic in tests. Weeks start on Monday.
enum QuickDatePreset {
  today('Today'),
  yesterday('Yesterday'),
  thisWeek('This week'),
  lastWeek('Last week'),
  thisMonth('This month'),
  lastMonth('Last month'),
  thisYear('This year');

  final String label;
  const QuickDatePreset(this.label);

  /// Presets shown as quick chips above the expense list.
  static const List<QuickDatePreset> quick = [today, thisWeek, thisMonth];

  /// Inclusive (start, end) days for this preset.
  (DateTime, DateTime) range({DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    switch (this) {
      case QuickDatePreset.today:
        return (today, today);
      case QuickDatePreset.yesterday:
        final y = today.subtract(const Duration(days: 1));
        return (y, y);
      case QuickDatePreset.thisWeek:
        return (monday, today);
      case QuickDatePreset.lastWeek:
        final lastMonday = monday.subtract(const Duration(days: 7));
        return (lastMonday, monday.subtract(const Duration(days: 1)));
      case QuickDatePreset.thisMonth:
        return (DateTime(n.year, n.month, 1), DateTime(n.year, n.month + 1, 0));
      case QuickDatePreset.lastMonth:
        return (DateTime(n.year, n.month - 1, 1), DateTime(n.year, n.month, 0));
      case QuickDatePreset.thisYear:
        return (DateTime(n.year, 1, 1), DateTime(n.year, 12, 31));
    }
  }

  bool matches(ExpenseHistoryFilter f, {DateTime? now}) {
    if (f.dateFrom == null || f.dateTo == null) return false;
    final r = range(now: now);
    return _sameDay(f.dateFrom!, r.$1) && _sameDay(f.dateTo!, r.$2);
  }

  /// Returns the preset matching the filter's date range, if any.
  static QuickDatePreset? of(ExpenseHistoryFilter f, {DateTime? now}) {
    for (final p in QuickDatePreset.values) {
      if (p.matches(f, now: now)) return p;
    }
    return null;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
