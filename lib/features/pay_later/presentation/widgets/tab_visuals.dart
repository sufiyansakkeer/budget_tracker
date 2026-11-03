import 'package:flutter/material.dart';

import '../../../expenses/domain/entities/expense_entity.dart';
import '../../domain/entities/pay_later_tab.dart';

/// The icon shown for a tab of [category], wherever tabs are listed.
IconData tabCategoryIcon(PayLaterTabCategory category) => switch (category) {
  PayLaterTabCategory.foodDining => Icons.restaurant_outlined,
  PayLaterTabCategory.groceries => Icons.shopping_basket_outlined,
  PayLaterTabCategory.shopping => Icons.shopping_bag_outlined,
  PayLaterTabCategory.personal => Icons.person_outline_rounded,
  PayLaterTabCategory.other => Icons.label_outline_rounded,
};

/// What a purchase on a tab is called in lists: its note, else its expense
/// category's name, else "Purchase".
String purchaseTitle(ExpenseEntity expense, {String? categoryName}) {
  final note = expense.note?.trim();
  if (note != null && note.isNotEmpty) return note;
  final name = categoryName?.trim();
  return (name == null || name.isEmpty) ? 'Purchase' : name;
}
