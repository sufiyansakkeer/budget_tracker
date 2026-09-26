import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/database/default_categories.dart';
import 'package:monivo/features/categories/domain/entities/category_catalog.dart';
import 'package:monivo/features/categories/domain/validators/category_validator.dart';
import 'package:monivo/features/expenses/presentation/widgets/category_visuals.dart';

void main() {
  group('CategoryValidator', () {
    test('name must be 1–40 characters after trimming', () {
      expect(CategoryValidator.validateName(null), 'Name cannot be empty');
      expect(CategoryValidator.validateName('   '), 'Name cannot be empty');
      expect(CategoryValidator.validateName('Coffee'), isNull);
      expect(CategoryValidator.validateName('a' * 40), isNull);
      expect(
        CategoryValidator.validateName('a' * 41),
        'Name must be 40 characters or fewer',
      );
    });

    test('icon must come from the catalog', () {
      expect(CategoryValidator.validateIcon(null), 'Choose an icon');
      expect(CategoryValidator.validateIcon('nope'), 'Unknown icon');
      expect(CategoryValidator.validateIcon('restaurant'), isNull);
    });

    test('colour must be #RRGGBB', () {
      expect(CategoryValidator.validateColor(null), 'Choose a colour');
      expect(
        CategoryValidator.validateColor('FF0000'),
        'Colour must be #RRGGBB',
      );
      expect(
        CategoryValidator.validateColor('#GG0000'),
        'Colour must be #RRGGBB',
      );
      expect(CategoryValidator.validateColor('#ff6b6b'), isNull);
    });

    test('names collide ignoring case and spaces', () {
      expect(CategoryValidator.sameName('Food', ' food '), isTrue);
      expect(CategoryValidator.sameName('Food', 'Foods'), isFalse);
    });
  });

  group('CategoryCatalog', () {
    test('every catalog icon has a dedicated Material glyph', () {
      final fallback = CategoryVisuals.iconFor('definitely-unknown');
      for (final name in CategoryCatalog.iconNames) {
        if (name == 'category') continue; // the fallback glyph itself
        expect(
          CategoryVisuals.iconFor(name),
          isNot(fallback),
          reason: '$name should map to its own icon',
        );
      }
    });

    test('every default category icon and colour is in the catalog', () {
      for (final row in defaultCategoryRows) {
        expect(CategoryCatalog.isKnownIcon(row.icon), isTrue, reason: row.id);
        expect(CategoryValidator.validateColor(row.colorHex), isNull);
      }
    });

    test('catalog colours are valid and unique', () {
      final set = CategoryCatalog.colorHexes.toSet();
      expect(set.length, CategoryCatalog.colorHexes.length);
      for (final hex in CategoryCatalog.colorHexes) {
        expect(CategoryValidator.validateColor(hex), isNull);
      }
    });
  });
}
