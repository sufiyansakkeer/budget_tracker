import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_header.dart';
import '../../domain/entities/report_period.dart';

/// Horizontal period selector used to switch report periods.
class PeriodSelector extends StatelessWidget {
  final ReportPeriod selected;
  final ValueChanged<ReportPeriod> onSelected;

  const PeriodSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final period in ReportPeriod.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(period.label),
                avatar: period.isCustom
                    ? const Icon(Icons.date_range_rounded)
                    : null,
                selected: period == selected,
                onSelected: (_) => onSelected(period),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shows the resolved date range for the current report, so a preset and a
/// custom range are equally clear. Tapping opens the custom range picker.
class ReportRangeLabel extends StatelessWidget {
  final ReportRange range;
  final VoidCallback onEdit;

  const ReportRangeLabel({
    super.key,
    required this.range,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = range.dayCount;
    return InkWell(
      onTap: onEdit,
      borderRadius: AppSpacing.borderRadiusSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: AppSizes.iconXs,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                '${formatDateRange(range.start, range.end)} · '
                '$days ${days == 1 ? 'day' : 'days'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              'Change',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
