import 'package:flutter/material.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../domain/entities/expense_category.dart';
import '../../../domain/entities/expense_history_filter.dart';
import '../../../domain/entities/quick_date_preset.dart';

export '../../../domain/entities/quick_date_preset.dart';
import '../../widgets/category_visuals.dart';

/// Quick-select chips for common filter shortcuts.
///
/// Date presets and the first few categories. Each chip only changes its own
/// part of the filter, so tapping "Today" never wipes a category or tag the
/// user set in the filter sheet.
class QuickFilterChips extends StatelessWidget {
  final ExpenseHistoryFilter current;
  final ValueChanged<ExpenseHistoryFilter> onSelected;

  /// Categories to offer as shortcuts (the first four are shown).
  final List<ExpenseCategory> categories;

  const QuickFilterChips({
    super.key,
    required this.current,
    required this.onSelected,
    this.categories = const [],
  });

  static const int _maxCategoryChips = 4;

  @override
  Widget build(BuildContext context) {
    final shortcuts = categories
        .where((c) => !c.isArchived)
        .take(_maxCategoryChips)
        .toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          _chip(
            label: 'Today',
            icon: Icons.today_rounded,
            selected: QuickDatePreset.today.matches(current),
            onTap: () => onSelected(_toggleDate(QuickDatePreset.today)),
          ),
          _chip(
            label: 'This Week',
            icon: Icons.date_range_rounded,
            selected: QuickDatePreset.thisWeek.matches(current),
            onTap: () => onSelected(_toggleDate(QuickDatePreset.thisWeek)),
          ),
          _chip(
            label: 'This Month',
            icon: Icons.calendar_month_rounded,
            selected: QuickDatePreset.thisMonth.matches(current),
            onTap: () => onSelected(_toggleDate(QuickDatePreset.thisMonth)),
          ),
          if (shortcuts.isNotEmpty) ...[
            const SizedBox(
              height: 24,
              child: VerticalDivider(width: AppSpacing.md),
            ),
            for (final category in shortcuts)
              _chip(
                label: category.name,
                icon: CategoryVisuals.iconFor(category.icon),
                selected: current.categoryId == category.id,
                onTap: () => onSelected(_toggleCategory(category.id)),
              ),
          ],
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
        avatar: Icon(icon, size: AppSizes.iconSm),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
      ),
    );
  }

  ExpenseHistoryFilter _toggleDate(QuickDatePreset preset) {
    if (preset.matches(current)) {
      return current.copyWithDateFrom(null).copyWithDateTo(null);
    }
    final range = preset.range();
    return current.copyWithDateRange(from: range.$1, to: range.$2);
  }

  ExpenseHistoryFilter _toggleCategory(String categoryId) {
    if (current.categoryId == categoryId) {
      return current.copyWithCategory(null);
    }
    return current.copyWithCategory(categoryId);
  }
}
