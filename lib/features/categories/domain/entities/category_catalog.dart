/// Icon names and colours a category may use.
///
/// Names are plain strings so the domain can validate them without Flutter;
/// `CategoryVisuals` (presentation) maps each name to a Material icon and a
/// test guarantees the two stay in sync.
abstract final class CategoryCatalog {
  static const List<String> iconNames = [
    'restaurant',
    'fastfood',
    'local_cafe',
    'local_grocery_store',
    'shopping_cart',
    'shopping_bag',
    'checkroom',
    'local_gas_station',
    'directions_car',
    'directions_bus',
    'train',
    'flight',
    'hotel',
    'home',
    'electric_bolt',
    'water_drop',
    'wifi',
    'phone_android',
    'laptop',
    'subscriptions',
    'movie',
    'music_note',
    'sports_esports',
    'fitness_center',
    'spa',
    'favorite',
    'local_hospital',
    'medication',
    'school',
    'child_care',
    'pets',
    'card_giftcard',
    'celebration',
    'volunteer_activism',
    'construction',
    'cleaning_services',
    'payments',
    'receipt_long',
    'account_balance_wallet',
    'savings',
    'work',
    'help_outline',
    'category',
  ];

  /// Hex colours (`#RRGGBB`) offered by the colour picker. Chosen to stay
  /// distinguishable from each other after `CategoryVisuals.adaptiveColor`.
  static const List<String> colorHexes = [
    '#FF6B6B',
    '#EE5253',
    '#FF9F43',
    '#FECA57',
    '#10AC84',
    '#1DD1A1',
    '#00D2D3',
    '#48DBFB',
    '#54A0FF',
    '#5F27CD',
    '#7C4DFF',
    '#FF9FF3',
    '#F368E0',
    '#8395A7',
    '#576574',
    '#795548',
  ];

  static bool isKnownIcon(String name) => iconNames.contains(name);
}
