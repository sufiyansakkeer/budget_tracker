import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
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
    final periods = ReportPeriod.values;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: periods.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final period = periods[index];
          final isSelected = period == selected;
          return ChoiceChip(
            label: Text(period.label),
            selected: isSelected,
            onSelected: (_) => onSelected(period),
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : null,
              fontWeight: isSelected ? FontWeight.bold : null,
            ),
          );
        },
      ),
    );
  }
}
