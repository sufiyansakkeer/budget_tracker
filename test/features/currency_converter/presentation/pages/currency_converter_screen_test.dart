import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/theme/app_theme.dart';
import 'package:monivo/features/currency_converter/data/repository/currency_converter_repository_impl.dart';
import 'package:monivo/features/currency_converter/domain/entities/exchange_rate_failure.dart';
import 'package:monivo/features/currency_converter/domain/usecases/converter_preferences_usecases.dart';
import 'package:monivo/features/currency_converter/domain/usecases/get_exchange_rate_usecase.dart';
import 'package:monivo/features/currency_converter/domain/usecases/get_supported_currencies_usecase.dart';
import 'package:monivo/features/currency_converter/presentation/bloc/currency_converter_bloc.dart';
import 'package:monivo/features/currency_converter/presentation/pages/currency_converter_screen.dart';

import '../../helpers/converter_fakes.dart';

void main() {
  late FakeCurrencyRemoteDataSource remote;
  late FakeCurrencyLocalDataSource local;

  setUp(() {
    remote = FakeCurrencyRemoteDataSource();
    local = FakeCurrencyLocalDataSource();
  });

  /// Builds the BLoC inside the test body (a BLoC created in setUp runs
  /// outside the fake-async zone and never progresses).
  Future<void> pumpScreen(WidgetTester tester) async {
    final repository = CurrencyConverterRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: local,
      clock: () => testNow,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: BlocProvider(
          create: (_) => CurrencyConverterBloc(
            getSupportedCurrencies: GetSupportedCurrenciesUseCase(
              repository: repository,
            ),
            getExchangeRate: GetExchangeRateUseCase(repository: repository),
            loadPreferences: LoadConverterPreferencesUseCase(
              repository: repository,
            ),
            savePreferences: SaveConverterPreferencesUseCase(
              repository: repository,
            ),
          )..add(const CurrencyConverterStarted()),
          child: const CurrencyConverterScreen(),
        ),
      ),
    );
    // Let the fakes answer, then let the entrance transitions finish.
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  String resultText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('converterResultText'))).data!;

  testWidgets('shows the converted amount, rate and its source', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Currency converter'), findsOneWidget);
    expect(resultText(tester), '₹249.33');
    expect(find.text('1 OMR = ₹249.33'), findsOneWidget);
    expect(find.text('Online rate'), findsOneWidget);
    expect(
      find.textContaining('Not a live market or bank rate'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('converterRefreshButton')), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const Key('converterAmountField')),
    );
    expect(field.controller!.text, '1');
  });

  testWidgets('typing converts locally without another request', (
    tester,
  ) async {
    await pumpScreen(tester);

    for (final (text, expected) in [
      ('10', '₹2,493.30'),
      ('50', '₹12,466.50'),
      ('100', '₹24,933.00'),
    ]) {
      await tester.enterText(
        find.byKey(const Key('converterAmountField')),
        text,
      );
      await tester.pump();
      expect(resultText(tester), expected, reason: text);
    }
    expect(remote.rateCalls, ['OMR_INR']);
  });

  testWidgets('invalid input shows validation, letters are ignored', (
    tester,
  ) async {
    await pumpScreen(tester);
    final field = find.byKey(const Key('converterAmountField'));

    await tester.enterText(field, '');
    await tester.pump();
    expect(find.text('Enter an amount'), findsOneWidget);

    await tester.enterText(field, '0');
    await tester.pump();
    expect(find.text('Enter an amount greater than 0'), findsOneWidget);

    await tester.enterText(field, '12abc');
    await tester.pump();
    // The formatter rejects the edit; the previous text stays.
    expect(tester.widget<TextField>(field).controller!.text, '0');
  });

  testWidgets('swap flips the pair and keeps the amount', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(
      find.byKey(const Key('converterAmountField')),
      '24933',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('converterSwapButton')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(resultText(tester), 'ر.ع.\u200E100.000');
    expect(find.text('Calculated from the OMR → INR rate'), findsOneWidget);
    expect(remote.rateCalls, ['OMR_INR']);
  });

  testWidgets('offline with no saved rate explains what is needed', (
    tester,
  ) async {
    remote.failWith = ExchangeRateFailure.noConnection;
    await pumpScreen(tester);

    expect(
      find.text(
        'An internet connection is required to get the exchange rate for '
        'this currency pair.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Something went wrong'), findsNothing);
    expect(find.byKey(const Key('converterRetryButton')), findsOneWidget);
    expect(find.byKey(const Key('converterRefreshButton')), findsNothing);
  });

  testWidgets('offline with a saved rate still converts', (tester) async {
    local.rates['OMR_INR'] = rateOf(
      'OMR',
      'INR',
      '248.00',
      rateDate: utcDay(2026, 9, 24),
      fetchedAt: DateTime.utc(2026, 9, 24, 9),
    );
    remote.failWith = ExchangeRateFailure.noConnection;
    await pumpScreen(tester);

    expect(resultText(tester), '₹248.00');
    expect(find.text('Offline'), findsOneWidget);
    expect(
      find.textContaining('Offline — using saved rate from'),
      findsOneWidget,
    );
  });

  testWidgets('refresh failure keeps the rate and tells the user', (
    tester,
  ) async {
    await pumpScreen(tester);
    remote.failWith = ExchangeRateFailure.noConnection;

    final refresh = find.byKey(const Key('converterRefreshButton'));
    await tester.ensureVisible(refresh);
    await tester.pumpAndSettle();
    await tester.tap(refresh);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text("Couldn't update. Using saved rate."), findsOneWidget);
    expect(resultText(tester), '₹249.33');
  });

  testWidgets('the currency picker lists and searches currencies', (
    tester,
  ) async {
    remote.rates['USD_INR'] = '87.05';
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('converterSourceField')));
    await tester.pumpAndSettle();
    expect(find.text('Convert from'), findsOneWidget);
    expect(find.text('Thai Baht'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'dollar');
    await tester.pump();
    expect(find.text('Thai Baht'), findsNothing);
    await tester.tap(find.text('US Dollar'));
    await tester.pumpAndSettle();

    expect(resultText(tester), '₹87.05');
  });
}
