import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../domain/entities/expense_category.dart';
import 'category_visuals.dart';

/// Modern visual category selector showing icon, name, and color.
/// Highlights the selected category with a filled, tinted chip.
class CategoryPicker extends StatelessWidget {
  final List<ExpenseCategory> categories;
  final String? selectedCategoryId;
  final ValueChanged<String> onSelected;

  const CategoryPicker({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (categories.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: categories.map((category) {
              final isSelected = category.id == selectedCategoryId;
              final color = CategoryVisuals.colorFor(category.colorHex);

              return ChoiceChip(
                key: Key('category_${category.id}'),
                selected: isSelected,
                onSelected: (_) => onSelected(category.id),
                avatar: Icon(
                  CategoryVisuals.iconFor(category.icon),
                  size: 18,
                  color: isSelected
                      ? color
                      : theme.colorScheme.onSurfaceVariant,
                ),
                label: Text(category.name),
                selectedColor: color.withValues(alpha: 0.18),
                backgroundColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
                showCheckmark: false,
                side: BorderSide(
                  color: isSelected
                      ? color.withValues(alpha: 0.8)
                      : Colors.transparent,
                  width: 1.5,
                ),
                labelStyle: TextStyle(
                  color: isSelected ? color : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
