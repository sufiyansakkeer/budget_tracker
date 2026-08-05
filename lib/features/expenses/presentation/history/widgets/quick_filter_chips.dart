import 'package:flutter/material.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../domain/entities/expense_history_filter.dart';

/// Quick-select chips for common filter shortcuts.
///
/// Each chip dispatches a whole [ExpenseHistoryFilter] so the caller can apply
/// the corresponding filter instantly.
class QuickFilterChips extends StatelessWidget {
  final ExpenseHistoryFilter current;
  final ValueChanged<ExpenseHistoryFilter> onSelected;

  const QuickFilterChips({
    super.key,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          _chip(
            label: 'Today',
            icon: Icons.today,
            selected: _isToday(current),
            onTap: () => onSelected(_todayFilter(current)),
          ),
          _chip(
            label: 'This Week',
            icon: Icons.view_week,
            selected: _isThisWeek(current),
            onTap: () => onSelected(_thisWeekFilter(current)),
          ),
          _chip(
            label: 'This Month',
            icon: Icons.calendar_month,
            selected: _isThisMonth(current),
            onTap: () => onSelected(_thisMonthFilter(current)),
          ),
          _divider(),
          _chip(
            label: 'Food',
            icon: Icons.restaurant,
            selected: current.categoryId == 'food',
            onTap: () => onSelected(_categoryFilter(current, 'food')),
          ),
          _chip(
            label: 'Grocery',
            icon: Icons.local_grocery_store,
            selected: current.categoryId == 'grocery',
            onTap: () => onSelected(_categoryFilter(current, 'grocery')),
          ),
          _chip(
            label: 'Fuel',
            icon: Icons.local_gas_station,
            selected: current.categoryId == 'fuel',
            onTap: () => onSelected(_categoryFilter(current, 'fuel')),
          ),
          _chip(
            label: 'Shopping',
            icon: Icons.shopping_cart,
            selected: current.categoryId == 'shopping',
            onTap: () => onSelected(_categoryFilter(current, 'shopping')),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: FilterChip(
        key: Key('quickFilter_$label'),
        label: Text(label),
        avatar: Icon(icon, size: 18),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }

  static Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: VerticalDivider(width: 1, thickness: 1),
    );
  }

  // ---- Filter builders ----

  ExpenseHistoryFilter _todayFilter(ExpenseHistoryFilter current) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    if (_isToday(current)) return const ExpenseHistoryFilter();
    return current.copyWithDateRange(from: start, to: start);
  }

  ExpenseHistoryFilter _thisWeekFilter(ExpenseHistoryFilter current) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: today.weekday - 1));
    final end = today;
    if (_isThisWeek(current)) return const ExpenseHistoryFilter();
    return current.copyWithDateRange(from: start, to: end);
  }

  ExpenseHistoryFilter _thisMonthFilter(ExpenseHistoryFilter current) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);
    if (_isThisMonth(current)) return const ExpenseHistoryFilter();
    return current.copyWithDateRange(from: start, to: end);
  }

  ExpenseHistoryFilter _categoryFilter(
    ExpenseHistoryFilter current,
    String categoryId,
  ) {
    if (current.categoryId == categoryId) {
      return current.copyWithCategory(null);
    }
    return current.copyWithCategory(categoryId);
  }

  // ---- Selection detector ----

  bool _isToday(ExpenseHistoryFilter f) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return f.dateFrom != null &&
        f.dateTo != null &&
        f.tags.isEmpty &&
        f.minAmount == null &&
        f.maxAmount == null &&
        !f.receiptOnly &&
        f.categoryId == null &&
        _sameDay(f.dateFrom!, today) &&
        _sameDay(f.dateTo!, today);
  }

  bool _isThisWeek(ExpenseHistoryFilter f) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: today.weekday - 1));
    return f.dateFrom != null &&
        f.dateTo != null &&
        f.tags.isEmpty &&
        f.minAmount == null &&
        f.maxAmount == null &&
        !f.receiptOnly &&
        f.categoryId == null &&
        _sameDay(f.dateFrom!, start) &&
        _sameDay(f.dateTo!, today);
  }

  bool _isThisMonth(ExpenseHistoryFilter f) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);
    return f.dateFrom != null &&
        f.dateTo != null &&
        f.tags.isEmpty &&
        f.minAmount == null &&
        f.maxAmount == null &&
        !f.receiptOnly &&
        f.categoryId == null &&
        _sameDay(f.dateFrom!, start) &&
        _sameDay(f.dateTo!, end);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
