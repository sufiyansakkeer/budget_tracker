import 'package:flutter/material.dart';

/// Maps category icon names to Material icons, and hex colors to Color.
class CategoryVisuals {
  CategoryVisuals._();

  static IconData iconFor(String iconName) {
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'local_grocery_store':
        return Icons.local_grocery_store_rounded;
      case 'local_gas_station':
        return Icons.local_gas_station_rounded;
      case 'shopping_cart':
        return Icons.shopping_cart_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'payments':
        return Icons.payments_rounded;
      case 'receipt_long':
      case 'receipt':
        return Icons.receipt_long_rounded;
      case 'flight':
        return Icons.flight_rounded;
      case 'movie':
        return Icons.movie_rounded;
      case 'favorite':
        return Icons.favorite_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  /// Parses a stored hex color (`#RRGGBB`, `RRGGBB` or `0xAARRGGBB`).
  ///
  /// Falls back to a neutral grey when the value cannot be parsed.
  static Color colorFor(String hexColor) {
    try {
      var hex = hexColor.trim().replaceAll('#', '');
      if (hex.toLowerCase().startsWith('0x')) hex = hex.substring(2);
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFF9E9E9E);
    }
  }

  /// Like [colorFor], but nudges the color toward better contrast on the
  /// current surface: lighter in dark mode, slightly deeper in light mode.
  static Color adaptiveColor(BuildContext context, String hexColor) {
    final base = colorFor(hexColor);
    final hsl = HSLColor.fromColor(base);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lightness = isDark
        ? hsl.lightness.clamp(0.55, 0.8)
        : hsl.lightness.clamp(0.28, 0.5);
    return hsl.withLightness(lightness).toColor();
  }
}
