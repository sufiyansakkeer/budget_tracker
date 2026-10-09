@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/biometric/app_lock_bloc.dart';
import 'package:monivo/core/biometric/biometric_gate_screen.dart';
import 'package:monivo/core/biometric/biometric_initializer.dart';
import 'package:monivo/features/currency_converter/data/repository/currency_converter_repository_impl.dart';
import 'package:monivo/features/currency_converter/domain/entities/converter_preferences.dart';
import 'package:monivo/features/currency_converter/domain/usecases/converter_preferences_usecases.dart';
import 'package:monivo/features/currency_converter/domain/usecases/get_exchange_rate_usecase.dart';
import 'package:monivo/features/currency_converter/domain/usecases/get_supported_currencies_usecase.dart';
import 'package:monivo/features/currency_converter/presentation/bloc/currency_converter_bloc.dart';
import 'package:monivo/features/currency_converter/presentation/pages/currency_converter_screen.dart';
import 'package:monivo/features/onboarding/presentation/bloc/onboarding_state.dart';
import 'package:monivo/features/onboarding/presentation/widgets/confirmation_step_widget.dart';

import '../features/currency_converter/helpers/converter_fakes.dart';
import 'golden_harness.dart';

/// The system prompt was dismissed: the gate rests on "Unlock".
class _DismissedPrompt implements BiometricInitializer {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> authenticateNow() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('onboarding confirmation', (tester) async {
    // ₹2,400 from 8 to 31 Oct: 24 days, ₹100 a day.
    final draft = OnboardingState(
      budgetNameInput: 'Personal',
      monthlyBudgetInput: '2400',
      parsedBudget: 2400,
      startDate: DateTime(2026, 10, 8),
      endDate: DateTime(2026, 10, 31),
    );
    await expectGoldenMatrix(
      tester,
      'onboarding_confirmation',
      Scaffold(
        body: SafeArea(
          child: ConfirmationStepWidget(
            state: draft,
            onCreateBudget: () {},
            onBack: () {},
          ),
        ),
      ),
    );
  }, skip: goldenSkip);

  testWidgets('currency converter', (tester) async {
    // Local times, so "Fetched today, 12:00 PM" is the same in every zone.
    final noon = DateTime(2026, 9, 26, 12);
    CurrencyConverterScreen.clock = () => noon;
    addTearDown(() => CurrencyConverterScreen.clock = DateTime.now);
    // Dollars, not rials: the test engine has no Arabic font.
    final local = FakeCurrencyLocalDataSource()
      ..preferences = const ConverterPreferences(
        sourceCode: 'USD',
        targetCode: 'INR',
        amountText: '25',
      );
    final repository = CurrencyConverterRepositoryImpl(
      remoteDataSource: FakeCurrencyRemoteDataSource(
        rates: {'USD_INR': '88.42', 'INR_USD': '0.01131'},
        clock: () => noon,
      ),
      localDataSource: local,
      clock: () => noon,
    );
    final bloc = CurrencyConverterBloc(
      getSupportedCurrencies: GetSupportedCurrenciesUseCase(
        repository: repository,
      ),
      getExchangeRate: GetExchangeRateUseCase(repository: repository),
      loadPreferences: LoadConverterPreferencesUseCase(repository: repository),
      savePreferences: SaveConverterPreferencesUseCase(repository: repository),
    )..add(const CurrencyConverterStarted());
    addTearDown(bloc.close);
    await expectGoldenMatrix(
      tester,
      'currency_converter',
      BlocProvider.value(value: bloc, child: const CurrencyConverterScreen()),
      size: const Size(360, 900),
    );
  }, skip: goldenSkip);

  testWidgets('lock screen', (tester) async {
    // The gate is its own app, themed from the platform here, so the matrix
    // is driven through the platform's brightness and text scale.
    await loadAppFonts();
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(360, 780) * 2.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final bloc = AppLockBloc(biometricInitializer: _DismissedPrompt());
    addTearDown(bloc.close);
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.pumpWidget(
          BlocProvider<AppLockBloc>.value(
            value: bloc,
            child: const BiometricGateScreen(child: SizedBox.shrink()),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/lock_screen.${brightness.name}.'
            '${scale.toStringAsFixed(0)}x.png',
          ),
        );
      }
    }
  }, skip: goldenSkip);
}
