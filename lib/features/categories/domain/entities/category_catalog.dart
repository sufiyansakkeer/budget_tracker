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

  /// Hex colours (`#RRGGBB`) offered by the colour picker, each with a name
  /// so a screen reader can tell the swatches apart. Chosen to stay
  /// distinguishable from each other after `CategoryVisuals.adaptiveColor`.
  static const Map<String, String> colorNames = {
    '#FF6B6B': 'Coral',
    '#EE5253': 'Red',
    '#FF9F43': 'Orange',
    '#FECA57': 'Amber',
    '#10AC84': 'Green',
    '#1DD1A1': 'Mint',
    '#00D2D3': 'Turquoise',
    '#48DBFB': 'Sky',
    '#54A0FF': 'Blue',
    '#5F27CD': 'Indigo',
    '#7C4DFF': 'Violet',
    '#FF9FF3': 'Pink',
    '#F368E0': 'Magenta',
    '#8395A7': 'Grey',
    '#576574': 'Slate',
    '#795548': 'Brown',
  };

  static List<String> get colorHexes => colorNames.keys.toList(growable: false);

  /// Display name for a catalogue colour, or "Colour" for an unknown one.
  static String colorName(String hex) =>
      colorNames[hex.toUpperCase()] ?? 'Colour';

  static bool isKnownIcon(String name) => iconNames.contains(name);
}
