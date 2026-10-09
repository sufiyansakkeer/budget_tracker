import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/currency/currency_formatter.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/theme/app_typography.dart';
import 'package:monivo/features/dashboard/presentation/widgets/safe_to_spend_copy.dart';
import 'package:monivo/features/settings/domain/entities/color_palette_entity.dart';
import 'package:monivo/features/settings/domain/entities/currency_entity.dart';

/// OMR uses the Central Bank of Oman's sign (U+20C4): to the left of the
/// figures, with a space. No system font draws it yet, so the app bundles
/// it as a fallback font, and text the system draws gets the old
/// abbreviation instead.
void main() {
  const sign = '⃄';

  group('the Omani rial sign', () {
    test('is the symbol for OMR', () {
      expect(CurrencyFormatter.omaniRialSign, sign);
      expect(currencyByCode('OMR').symbol, sign);
      expect(CurrencyFormatter.symbolFor('OMR'), sign);
    });

    test('goes before the figures with a no-break space', () {
      expect(CurrencyFormatter.format(7.6, code: 'OMR'), '$sign 7.600');
      expect(CurrencyFormatter.format(1234.5, code: 'OMR'), '$sign 1,234.500');
      expect(
        CurrencyFormatter.formatFloored(4.54545, code: 'OMR'),
        '$sign 4.545',
      );
      expect(SafeToSpendCopy.amount(-12.5, 'OMR'), '−$sign 12.500');
    });

    test('text the system draws gets the old abbreviation', () {
      expect(
        CurrencyFormatter.forSystemText("Today's Safe Spending: $sign 7.600"),
        "Today's Safe Spending: ر.ع.‎7.600",
      );
      // Anything else is untouched.
      expect(CurrencyFormatter.forSystemText('₹1,250 left'), '₹1,250 left');
    });

    test('screen readers hear the currency code', () {
      expect(CurrencyFormatter.forSpeech('$sign 7.600 left'), 'OMR 7.600 left');
      expect(CurrencyFormatter.forSpeech('₹1,250'), '₹1,250');
    });

    test('every text style can draw it', () {
      const fallback = AppTypography.fontFamilyFallback;
      expect(fallback, contains('MonivoOmaniRial'));
      for (final palette in [ColorPalette.defaultPalette, ColorPalette.ocean]) {
        for (final theme in [
          AppTheme.buildLightTheme(palette),
          AppTheme.buildDarkTheme(palette),
        ]) {
          final t = theme.textTheme;
          for (final style in [
            t.displaySmall,
            t.headlineMedium,
            t.headlineSmall,
            t.titleLarge,
            t.titleMedium,
            t.titleSmall,
            t.bodyLarge,
            t.bodyMedium,
            t.bodySmall,
            t.labelLarge,
            t.labelMedium,
            t.labelSmall,
          ]) {
            expect(style?.fontFamilyFallback, fallback);
          }
        }
      }
      const money = AppTypography.standard;
      for (final style in [
        money.moneyHero,
        money.moneyDisplay,
        money.moneyTitle,
        money.moneyBody,
        money.moneyCaption,
        money.eyebrow,
      ]) {
        expect(style.fontFamilyFallback, fallback);
      }
    });
  });

  group('Arabic-script symbols in sentences', () {
    test('stay before the digits', () {
      // Without the left-to-right mark "د.إ1,000" draws as "1,000د.إ".
      expect(CurrencyFormatter.format(1000, code: 'AED'), 'د.إ‎1,000');
      expect(SafeToSpendCopy.amount(1000, 'AED'), 'د.إ‎1,000');
      expect(
        "You've spent ${SafeToSpendCopy.amount(250, 'AED')} more than "
            "${SafeToSpendCopy.amount(1000, 'AED')}.",
        "You've spent د.إ‎250 more than د.إ‎1,000.",
      );
    });
  });
}
