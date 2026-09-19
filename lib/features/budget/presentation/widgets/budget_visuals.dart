import 'package:flutter/material.dart';

import '../../../../core/domain/entities/budget_entity.dart';
import '../../../expenses/presentation/widgets/category_visuals.dart';

/// Shared icon/colour mapping for budgets so the list, form and details
/// screens always draw a budget the same way.
class BudgetVisuals {
  BudgetVisuals._();

  /// Icon choices offered in the budget form, with accessible labels.
  static const List<(String, String, IconData)> iconOptions = [
    ('personal', 'Personal', Icons.person_rounded),
    ('family', 'Family', Icons.family_restroom_rounded),
    ('vacation', 'Vacation', Icons.beach_access_rounded),
    ('wedding', 'Wedding', Icons.favorite_rounded),
    ('business', 'Business', Icons.business_center_rounded),
    ('travel', 'Travel', Icons.flight_takeoff_rounded),
    ('home', 'Home', Icons.home_rounded),
  ];

  /// Colour choices offered in the budget form (stored as `0xAARRGGBB`).
  static const List<(String, String)> colorOptions = [
    ('0xFF2196F3', 'Blue'),
    ('0xFF4CAF50', 'Green'),
    ('0xFFFF9800', 'Orange'),
    ('0xFFF44336', 'Red'),
    ('0xFF9C27B0', 'Purple'),
    ('0xFF009688', 'Teal'),
  ];

  static IconData iconFor(String? name) {
    for (final option in iconOptions) {
      if (option.$1 == name) return option.$3;
    }
    return Icons.account_balance_wallet_rounded;
  }

  /// The budget's accent colour, adapted for contrast on the current theme,
  /// falling back to the palette primary.
  static Color colorFor(BuildContext context, BudgetEntity budget) {
    final hex = budget.color;
    if (hex == null || hex.isEmpty) {
      return Theme.of(context).colorScheme.primary;
    }
    return CategoryVisuals.adaptiveColor(context, hex);
  }

  /// Raw (un-adapted) colour for a stored hex, used for swatches.
  static Color rawColor(String hex) => CategoryVisuals.colorFor(hex);
}

/// Lifecycle of a budget relative to today.
enum BudgetPhase { running, upcoming, ended, archived }

extension BudgetPhaseX on BudgetEntity {
  BudgetPhase phaseOn(DateTime now) {
    if (isArchived) return BudgetPhase.archived;
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    if (today.isBefore(start)) return BudgetPhase.upcoming;
    if (today.isAfter(end)) return BudgetPhase.ended;
    return BudgetPhase.running;
  }
}
