import '../entities/category_catalog.dart';

/// Pure validation rules for category input. Returns a message or null.
abstract final class CategoryValidator {
  static const int maxNameLength = 40;

  static final RegExp _hex = RegExp(r'^#[0-9A-Fa-f]{6}$');

  static String? validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Name cannot be empty';
    if (name.length > maxNameLength) {
      return 'Name must be $maxNameLength characters or fewer';
    }
    return null;
  }

  static String? validateIcon(String? value) {
    if (value == null || value.isEmpty) return 'Choose an icon';
    if (!CategoryCatalog.isKnownIcon(value)) return 'Unknown icon';
    return null;
  }

  static String? validateColor(String? value) {
    if (value == null || value.isEmpty) return 'Choose a colour';
    if (!_hex.hasMatch(value.trim())) return 'Colour must be #RRGGBB';
    return null;
  }

  /// Two names collide when they match ignoring case and surrounding spaces.
  static bool sameName(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();
}
