import 'package:equatable/equatable.dart';
import '../../../../core/database/default_categories.dart';

/// Expense category model. Supports system and custom categories.
class ExpenseCategory extends Equatable {
  final String id;
  final String name;
  final String icon;
  final String colorHex;

  /// Seeded by the app. System categories can be edited but not deleted.
  final bool isSystem;

  /// Hidden from pickers and quick filters; existing expenses keep it.
  final bool isArchived;

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorHex,
    this.isSystem = true,
    this.isArchived = false,
  });

  ExpenseCategory copyWith({
    String? name,
    String? icon,
    String? colorHex,
    bool? isSystem,
    bool? isArchived,
  }) {
    return ExpenseCategory(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      isSystem: isSystem ?? this.isSystem,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  @override
  List<Object?> get props => [id, name, icon, colorHex, isSystem, isArchived];
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
