import 'package:flutter/material.dart';

/// Maps category icon names to Material icons, and hex colors to Color.
class CategoryVisuals {
  CategoryVisuals._();

  static IconData iconFor(String iconName) {
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant;
      case 'local_grocery_store':
        return Icons.local_grocery_store;
      case 'local_gas_station':
        return Icons.local_gas_station;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'home':
        return Icons.home;
      case 'payments':
        return Icons.payments;
      case 'receipt_long':
        return Icons.receipt_long;
      case 'flight':
        return Icons.flight;
      case 'movie':
        return Icons.movie;
      case 'favorite':
        return Icons.favorite;
      case 'school':
        return Icons.school;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet;
      default:
        return Icons.help_outline;
    }
  }

  static Color colorFor(String hexColor) {
    try {
      final color = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$color', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}
