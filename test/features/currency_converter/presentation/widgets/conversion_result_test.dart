import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/currency/currency_formatter.dart';
import 'package:monivo/core/currency/exact_decimal.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/currency_converter/domain/entities/rate_lookup.dart';
import 'package:monivo/features/currency_converter/presentation/widgets/conversion_result.dart';
import 'package:monivo/features/settings/domain/entities/currency_entity.dart';

import '../../helpers/converter_fakes.dart';

/// UX-103: the "… is about" line was one line with an ellipsis.
void main() {
  testWidgets('a long amount at 200% text reads in full', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.reset);

    final omr = availableCurrencies.firstWhere((c) => c.code == 'OMR');
    final inr = availableCurrencies.firstWhere((c) => c.code == 'INR');
    final amount = ExactDecimal.parse('1234567.125');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 800),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: ConversionResult(
                source: omr,
                target: inr,
                amount: amount,
                result: ExactDecimal.parse('274000000.5'),
                rate: RateLookup(
                  rate: rateOf('OMR', 'INR', '221.94'),
                  origin: RateOrigin.online,
                ),
                failure: null,
                onRetry: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final source = CurrencyFormatter.formatDecimal(
      amount,
      symbol: omr.symbol,
      decimalDigits: 3,
    );
    final lead = find.text('$source OMR is about');
    expect(lead, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(lead);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });
}
