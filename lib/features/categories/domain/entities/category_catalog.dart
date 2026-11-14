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
  /// so a screen reader can tell the swatches apart. Every default category
  /// colour is here, so editing a built-in category shows its colour
  /// selected. Only the defaults are guaranteed distinct as drawn (see
  /// `default_category_colours_test.dart`); the older entries are kept
  /// because existing categories use them.
  static const Map<String, String> colorNames = {
    '#FF6B6B': 'Coral',
    '#EE5253': 'Red',
    '#883311': 'Brick',
    '#FF9F43': 'Orange',
    '#FECA57': 'Amber',
    '#F1C40F': 'Yellow',
    '#8BC34A': 'Lime',
    '#10AC84': 'Green',
    '#1DD1A1': 'Mint',
    '#00D2D3': 'Turquoise',
    '#48DBFB': 'Sky',
    '#54A0FF': 'Blue',
    '#5F27CD': 'Indigo',
    '#7C4DFF': 'Violet',
    '#6F1E51': 'Plum',
    '#FF9FF3': 'Pink',
    '#F368E0': 'Magenta',
    '#C9A0A0': 'Rose',
    '#8395A7': 'Grey',
    '#8A8A8A': 'Ash',
    '#576574': 'Slate',
    '#795548': 'Brown',
  };

  static List<String> get colorHexes => colorNames.keys.toList(growable: false);

  /// Display name for a catalogue colour, or "Colour" for an unknown one.
  static String colorName(String hex) =>
      colorNames[hex.toUpperCase()] ?? 'Colour';

  static bool isKnownIcon(String name) => iconNames.contains(name);
}
