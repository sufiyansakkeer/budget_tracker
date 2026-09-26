import 'package:flutter/material.dart';

import '../../../../core/theme/contrast.dart';

/// Maps category icon names to Material icons, and hex colors to Color.
class CategoryVisuals {
  CategoryVisuals._();

  /// Material icon for a catalog icon name (see `CategoryCatalog.iconNames`).
  /// Unknown names fall back to a generic category glyph.
  static IconData iconFor(String iconName) => _icons[iconName] ?? _fallback;

  static const IconData _fallback = Icons.category_rounded;

  static const Map<String, IconData> _icons = {
    'restaurant': Icons.restaurant_rounded,
    'fastfood': Icons.fastfood_rounded,
    'local_cafe': Icons.local_cafe_rounded,
    'local_grocery_store': Icons.local_grocery_store_rounded,
    'shopping_cart': Icons.shopping_cart_rounded,
    'shopping_bag': Icons.shopping_bag_rounded,
    'checkroom': Icons.checkroom_rounded,
    'local_gas_station': Icons.local_gas_station_rounded,
    'directions_car': Icons.directions_car_rounded,
    'directions_bus': Icons.directions_bus_rounded,
    'train': Icons.train_rounded,
    'flight': Icons.flight_rounded,
    'hotel': Icons.hotel_rounded,
    'home': Icons.home_rounded,
    'electric_bolt': Icons.electric_bolt_rounded,
    'water_drop': Icons.water_drop_rounded,
    'wifi': Icons.wifi_rounded,
    'phone_android': Icons.phone_android_rounded,
    'laptop': Icons.laptop_rounded,
    'subscriptions': Icons.subscriptions_rounded,
    'movie': Icons.movie_rounded,
    'music_note': Icons.music_note_rounded,
    'sports_esports': Icons.sports_esports_rounded,
    'fitness_center': Icons.fitness_center_rounded,
    'spa': Icons.spa_rounded,
    'favorite': Icons.favorite_rounded,
    'local_hospital': Icons.local_hospital_rounded,
    'medication': Icons.medication_rounded,
    'school': Icons.school_rounded,
    'child_care': Icons.child_care_rounded,
    'pets': Icons.pets_rounded,
    'card_giftcard': Icons.card_giftcard_rounded,
    'celebration': Icons.celebration_rounded,
    'volunteer_activism': Icons.volunteer_activism_rounded,
    'construction': Icons.construction_rounded,
    'cleaning_services': Icons.cleaning_services_rounded,
    'payments': Icons.payments_rounded,
    'receipt_long': Icons.receipt_long_rounded,
    'receipt': Icons.receipt_long_rounded,
    'account_balance_wallet': Icons.account_balance_wallet_rounded,
    'savings': Icons.savings_rounded,
    'work': Icons.work_rounded,
    'help_outline': Icons.help_outline_rounded,
    'category': Icons.category_rounded,
  };

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

  /// Like [colorFor], but adjusted until it is legible as text on the current
  /// surface.
  ///
  /// Category colours are chosen for identity, not legibility: several of the
  /// catalogue's brighter hues land below 2:1 on a white surface. Clamping
  /// lightness is not enough — lightness is not luminance, so a saturated
  /// cyan stays unreadable at any "reasonable" lightness. This keeps the hue
  /// and moves lightness only as far as WCAG AA requires.
  static Color adaptiveColor(BuildContext context, String hexColor) {
    return Contrast.ensureContrast(
      colorFor(hexColor),
      Theme.of(context).colorScheme.surface,
    );
  }
}
