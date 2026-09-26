import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../domain/entities/expense_category.dart';
import 'category_visuals.dart';
import 'form_field_error.dart';
import '../../../../core/constants/app_motion.dart';

/// Visual category selector: icon + name chips, tinted with the category
/// color when selected.
class CategoryPicker extends StatelessWidget {
  final List<ExpenseCategory> categories;
  final String? selectedCategoryId;
  final ValueChanged<String> onSelected;
  final String? errorText;

  const CategoryPicker({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        if (categories.isEmpty)
          Shimmer(
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final w in [88.0, 104.0, 72.0, 96.0, 80.0])
                  SkeletonBox(
                    width: w,
                    height: 36,
                    radius: AppSpacing.radiusFull,
                  ),
                // Keep a progress indicator for assistive tech + tests.
                const SizedBox(
                  width: AppSizes.iconMd,
                  height: AppSizes.iconMd,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: categories
                .where((c) => !c.isArchived || c.id == selectedCategoryId)
                .map((category) {
                  final isSelected = category.id == selectedCategoryId;
                  final color = CategoryVisuals.adaptiveColor(
                    context,
                    category.colorHex,
                  );
                  // The chosen chip lifts slightly so the selection reads at a
                  // glance; the chip itself animates its colours.
                  return AnimatedScale(
                    scale: isSelected ? 1.04 : 1,
                    duration: AppMotion.respectReducedMotion(
                      context,
                      AppMotion.fast,
                    ),
                    curve: AppMotion.standardCurve,
                    child: ChoiceChip(
                      key: Key('category_${category.id}'),
                      selected: isSelected,
                      onSelected: (_) => onSelected(category.id),
                      avatar: Icon(
                        CategoryVisuals.iconFor(category.icon),
                        size: AppSizes.iconSm + 2,
                        color: isSelected
                            ? color
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      label: Text(category.name),
                      selectedColor: color.withValues(alpha: 0.16),
                      side: BorderSide(
                        color: isSelected
                            ? color
                            : theme.colorScheme.outlineVariant,
                      ),
                      labelStyle: theme.textTheme.labelLarge?.copyWith(
                        color: isSelected ? color : theme.colorScheme.onSurface,
                      ),
                    ),
                  );
                })
                .toList(),
          ),
        if (errorText != null) FormFieldError(message: errorText!),
      ],
    );
  }
}
