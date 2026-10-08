import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/core/theme/app_typography.dart';
import 'package:monivo/core/widgets/app_money.dart';

void main() {
  Widget harness(Widget child, {bool reduceMotion = false}) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );

  String plain(WidgetTester tester) {
    final text = tester.widget<Text>(find.byType(Text).last);
    return text.data ?? text.textSpan!.toPlainText();
  }

  group('AppMoney.format', () {
    test('whole amounts carry no decimals; fractions keep minor units', () {
      expect(AppMoney.format(250, currency: 'INR'), '₹250');
      expect(AppMoney.format(249.5, currency: 'INR'), '₹249.50');
      expect(AppMoney.format(1250, currency: 'INR'), '₹1,250');
    });

    test('safe amounts are floored to the digits shown, never rounded up', () {
      expect(
        AppMoney.format(333.339, currency: 'INR', floored: true),
        '₹333.33',
      );
      expect(AppMoney.format(714.6, currency: 'INR'), '₹714.60');
    });

    test(
      'OMR keeps its three decimals and is never rounded to a whole rial',
      () {
        final text = AppMoney.format(7.6, currency: 'OMR', floored: true);
        expect(text, contains('7.600'));
        expect(text, isNot(contains('8')));
      },
    );

    test('negatives use a true minus sign; inflows can show a plus', () {
      expect(AppMoney.format(-300, currency: 'INR'), '−₹300');
      expect(AppMoney.format(300, currency: 'INR', showPlus: true), '+₹300');
      // A value that rounds to zero is never signed.
      expect(AppMoney.format(-0.001, currency: 'INR'), '₹0');
    });

    test('an Arabic-script symbol is followed by a left-to-right mark', () {
      final text = AppMoney.format(12.45, currency: 'OMR');
      expect(text, startsWith('ر.ع.‎'));
      expect(text, endsWith('12.450'));
    });
  });

  group('AppMoney widget', () {
    testWidgets('draws the formatted amount in the role style with tabular '
        'figures', (tester) async {
      await tester.pumpWidget(
        harness(const AppMoney(amount: 1250, currency: 'INR')),
      );
      expect(find.text('₹1,250'), findsOneWidget);
      final text = tester.widget<Text>(find.text('₹1,250'));
      expect(
        text.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(text.style!.fontSize, AppTypography.standard.moneyBody.fontSize);
    });

    testWidgets('split keeps the plain text identical to the formatter', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const AppMoney(
            amount: 867.625,
            currency: 'INR',
            role: MoneyRole.hero,
            floored: true,
            split: true,
          ),
        ),
      );
      expect(plain(tester), '₹867.62');
      final span =
          tester.widget<Text>(find.byType(Text).last).textSpan! as TextSpan;
      final parts = span.children!.cast<TextSpan>();
      final whole = parts.firstWhere((p) => p.text == '867');
      final fraction = parts.firstWhere((p) => p.text == '.62');
      expect(fraction.style!.fontSize, whole.style!.fontSize! / 2);
    });

    testWidgets('speaks the amount, with "minus" for negatives', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(const AppMoney(amount: -300, currency: 'INR')),
      );
      expect(find.bySemanticsLabel('minus ₹300'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a change cross-fades instead of counting through values', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(const AppMoney(amount: 100, currency: 'INR')),
      );
      await tester.pumpWidget(
        harness(const AppMoney(amount: 900, currency: 'INR')),
      );
      await tester.pump(const Duration(milliseconds: 50));
      // Mid-transition only the old and new figures exist, never ₹500.
      expect(find.text('₹100'), findsOneWidget);
      expect(find.text('₹900'), findsOneWidget);
      expect(find.textContaining('₹5'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('₹100'), findsNothing);
      expect(find.text('₹900'), findsOneWidget);
    });

    testWidgets('reduced motion swaps the figure instantly', (tester) async {
      await tester.pumpWidget(
        harness(
          const AppMoney(amount: 100, currency: 'INR'),
          reduceMotion: true,
        ),
      );
      await tester.pumpWidget(
        harness(
          const AppMoney(amount: 900, currency: 'INR'),
          reduceMotion: true,
        ),
      );
      await tester.pump();
      expect(find.text('₹100'), findsNothing);
      expect(find.text('₹900'), findsOneWidget);
    });
  });
}
