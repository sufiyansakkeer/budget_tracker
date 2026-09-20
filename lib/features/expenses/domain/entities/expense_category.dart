import 'package:equatable/equatable.dart';
import '../../../../core/database/default_categories.dart';

/// Expense category model. Supports system and custom categories.
class ExpenseCategory extends Equatable {
  final String id;
  final String name;
  final String icon;
  final String colorHex;
  final bool isSystem;

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorHex,
    this.isSystem = true,
  });

  @override
  List<Object?> get props => [id, name, icon, colorHex, isSystem];
}

/// Default system categories seeded into the database.
/// Default categories, mapped from the core seed list so the database and
/// the domain can never disagree about ids.
final List<ExpenseCategory> defaultCategories = defaultCategoryRows
    .map(
      (row) => ExpenseCategory(
        id: row.id,
        name: row.name,
        icon: row.icon,
        colorHex: row.colorHex,
      ),
    )
    .toList(growable: false);
