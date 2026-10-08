import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/currency/currency_formatter.dart';

void main() {
  group('floorToDigits', () {
    test('floors to the given digits, never rounding up', () {
      expect(CurrencyFormatter.floorToDigits(714.2857142857143, 2), 714.28);
      expect(CurrencyFormatter.floorToDigits(714.6, 0), 714);
      expect(CurrencyFormatter.floorToDigits(1000 / 3, 2), 333.33);
      expect(CurrencyFormatter.floorToDigits(7.6789, 3), 7.678);
    });

    test('binary noise never loses a whole minor unit', () {
      // 0.29 × 100 = 28.999999999999996 in binary.
      expect(CurrencyFormatter.floorToDigits(0.29, 2), 0.29);
      expect(CurrencyFormatter.floorToDigits(0.1 + 0.2, 2), 0.3);
      expect(CurrencyFormatter.floorToDigits(7.6, 3), 7.6);
      expect(CurrencyFormatter.floorToDigits(1.005, 3), 1.005);
    });

    test('whole and zero amounts are unchanged', () {
      expect(CurrencyFormatter.floorToDigits(1000, 2), 1000);
      expect(CurrencyFormatter.floorToDigits(0, 3), 0);
    });
  });

  group('floorForDisplay', () {
    test('OMR keeps its 3 decimals when there is a fraction', () {
      final d = CurrencyFormatter.floorForDisplay(7.6, code: 'OMR');
      expect(d.amount, 7.6);
      expect(d.decimalDigits, 3);
    });

    test('whole floored values show no decimals', () {
      final omr = CurrencyFormatter.floorForDisplay(12, code: 'OMR');
      expect(omr.amount, 12);
      expect(omr.decimalDigits, 0);
      // 1000.004 floors to 1000.00 at INR precision → whole.
      final inr = CurrencyFormatter.floorForDisplay(1000.004, code: 'INR');
      expect(inr.amount, 1000);
      expect(inr.decimalDigits, 0);
    });

    test('INR floors to 2 decimals', () {
      final d = CurrencyFormatter.floorForDisplay(1000 / 3, code: 'INR');
      expect(d.amount, 333.33);
      expect(d.decimalDigits, 2);
    });

    test('JPY floors to whole yen', () {
      final d = CurrencyFormatter.floorForDisplay(99.9, code: 'JPY');
      expect(d.amount, 99);
      expect(d.decimalDigits, 0);
    });
  });

  group('formatFloored', () {
    test('OMR 7.600 never renders as 8', () {
      final text = CurrencyFormatter.formatFloored(7.6, code: 'OMR');
      expect(text, contains('7.600'));
      expect(text, isNot(contains('8')));
    });

    test('INR 714.6 renders 714.60, not 715', () {
      final text = CurrencyFormatter.formatFloored(714.6, code: 'INR');
      expect(text, '₹714.60');
    });

    test('INR 15000/21 renders 714.28, not 714.29', () {
      expect(
        CurrencyFormatter.formatFloored(15000 / 21, code: 'INR'),
        '₹714.28',
      );
    });

    test('whole amounts render without decimals', () {
      expect(CurrencyFormatter.formatFloored(1000, code: 'INR'), '₹1,000');
    });
  });
}
