import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../domain/entities/expense_category.dart';
import 'category_visuals.dart';
import 'form_field_error.dart';
import '../../../../core/constants/app_motion.dart';

/// Visual category selector: icon + name chips. The icon carries the
/// category's colour; the selected chip uses the theme's neutral selection.
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
          // Chip-shaped placeholders, announced once; no spinner.
          Semantics(
            label: 'Loading categories',
            excludeSemantics: true,
            child: Shimmer(
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final w in [88.0, 104.0, 72.0, 96.0, 80.0])
                    SkeletonBox(
                      width: w,
                      height: 32,
                      radius: AppSpacing.radiusSm,
                    ),
                ],
              ),
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
                    // Selection is neutral (the theme's selected chip), so a
                    // red or amber category never reads as a warning; the
                    // icon keeps the category's colour.
                    child: ChoiceChip(
                      key: Key('category_${category.id}'),
                      selected: isSelected,
                      showCheckmark: false,
                      onSelected: (_) => onSelected(category.id),
                      avatar: Icon(
                        CategoryVisuals.iconFor(category.icon),
                        size: AppSizes.iconSm + 2,
                        color: color,
                      ),
                      label: Text(category.name),
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
