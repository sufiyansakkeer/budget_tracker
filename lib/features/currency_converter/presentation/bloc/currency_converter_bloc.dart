import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/currency/exact_decimal.dart';
import '../../../settings/domain/entities/currency_entity.dart';
import '../../domain/entities/converter_preferences.dart';
import '../../domain/entities/exchange_rate_failure.dart';
import '../../domain/entities/rate_lookup.dart';
import '../../domain/usecases/convert_amount_usecase.dart';
import '../../domain/usecases/converter_preferences_usecases.dart';
import '../../domain/usecases/get_exchange_rate_usecase.dart';
import '../../domain/usecases/get_supported_currencies_usecase.dart';
import '../../domain/validators/amount_input_validator.dart';
import 'currency_converter_event.dart';
import 'currency_converter_state.dart';

export 'currency_converter_event.dart';
export 'currency_converter_state.dart';

/// Currency converter state.
///
/// Network access is only ever reached through [GetExchangeRateUseCase],
/// and only from [CurrencyConverterStarted], a pair change, a swap, a
/// refresh or a retry. Amount changes convert locally with the loaded rate.
class CurrencyConverterBloc
    extends Bloc<CurrencyConverterEvent, CurrencyConverterState> {
  final GetSupportedCurrenciesUseCase getSupportedCurrencies;
  final GetExchangeRateUseCase getExchangeRate;
  final ConvertAmountUseCase convertAmount;
  final LoadConverterPreferencesUseCase loadPreferences;
  final SaveConverterPreferencesUseCase savePreferences;
  final AmountInputValidator amountValidator;

  /// What gets saved as the amount: the field may be mid-edit (empty or
  /// invalid) when the pair changes.
  String _lastValidAmountText = ConverterPreferences.defaults.amountText;

  CurrencyConverterBloc({
    required this.getSupportedCurrencies,
    required this.getExchangeRate,
    required this.loadPreferences,
    required this.savePreferences,
    this.convertAmount = const ConvertAmountUseCase(),
    this.amountValidator = const AmountInputValidator(),
  }) : super(
         CurrencyConverterState(
           source: _fallbackEntity(ConverterPreferences.defaults.sourceCode),
           target: _fallbackEntity(ConverterPreferences.defaults.targetCode),
         ),
       ) {
    on<CurrencyConverterStarted>(_onStarted);
    on<CurrencyConverterSourceSelected>(_onSourceSelected);
    on<CurrencyConverterTargetSelected>(_onTargetSelected);
    on<CurrencyConverterAmountChanged>(_onAmountChanged);
    on<CurrencyConverterSwapped>(_onSwapped);
    on<CurrencyConverterRateRefreshed>(_onRateRefreshed);
    on<CurrencyConverterRetried>(_onRetried);
    on<CurrencyConverterNoticeCleared>(
      (event, emit) => emit(state.copyWith(notice: null)),
    );
  }

  Future<void> _onStarted(
    CurrencyConverterStarted event,
    Emitter<CurrencyConverterState> emit,
  ) async {
    if (state.isRestored) return;
    emit(
      state.copyWith(
        currencyListStatus: CurrencyListStatus.loading,
        rateStatus: RateStatus.loading,
      ),
    );

    final preferences = await loadPreferences();
    final validation = amountValidator.validate(preferences.amountText);
    if (validation.isValid) _lastValidAmountText = preferences.amountText;
    emit(
      state.copyWith(
        source: _entityFor(preferences.sourceCode),
        target: _entityFor(preferences.targetCode),
        amountText: preferences.amountText,
        amount: validation.value,
        amountError: validation.error,
        isRestored: true,
      ),
    );

    // Independent: a cached rate should not wait for the currency list.
    await Future.wait([_loadCurrencies(emit), _loadRate(emit)]);
  }

  Future<void> _onSourceSelected(
    CurrencyConverterSourceSelected event,
    Emitter<CurrencyConverterState> emit,
  ) async {
    final code = event.code.toUpperCase();
    if (code == state.source.code) return;
    if (code == state.target.code) return _swap(emit);
    emit(state.copyWith(source: _entityFor(code)));
    _persist();
    await _loadRate(emit);
  }

  Future<void> _onTargetSelected(
    CurrencyConverterTargetSelected event,
    Emitter<CurrencyConverterState> emit,
  ) async {
    final code = event.code.toUpperCase();
    if (code == state.target.code) return;
    if (code == state.source.code) return _swap(emit);
    emit(state.copyWith(target: _entityFor(code)));
    _persist();
    await _loadRate(emit);
  }

  void _onAmountChanged(
    CurrencyConverterAmountChanged event,
    Emitter<CurrencyConverterState> emit,
  ) {
    if (event.text == state.amountText) return;
    final validation = amountValidator.validate(event.text);
    emit(
      state.copyWith(
        amountText: event.text,
        amount: validation.value,
        amountError: validation.error,
        result: _convert(validation.value, state.rate),
      ),
    );
    if (validation.isValid) {
      _lastValidAmountText = event.text;
      _persist();
    }
  }

  Future<void> _onSwapped(
    CurrencyConverterSwapped event,
    Emitter<CurrencyConverterState> emit,
  ) => _swap(emit);

  Future<void> _swap(Emitter<CurrencyConverterState> emit) async {
    emit(
      state.copyWith(
        source: state.target,
        target: state.source,
        swapCount: state.swapCount + 1,
      ),
    );
    _persist();
    await _loadRate(emit);
  }

  Future<void> _onRateRefreshed(
    CurrencyConverterRateRefreshed event,
    Emitter<CurrencyConverterState> emit,
  ) async {
    // Ignore repeated taps and taps while a pair is still loading.
    if (state.isRefreshing || state.rateStatus == RateStatus.loading) return;
    await _loadRate(emit, forceRefresh: true);
  }

  Future<void> _onRetried(
    CurrencyConverterRetried event,
    Emitter<CurrencyConverterState> emit,
  ) async {
    if (state.rateStatus == RateStatus.loading) return;
    await Future.wait([
      if (state.currencyListIsPartial) _loadCurrencies(emit),
      _loadRate(emit),
    ]);
  }

  Future<void> _loadCurrencies(Emitter<CurrencyConverterState> emit) async {
    emit(state.copyWith(currencyListStatus: CurrencyListStatus.loading));
    final list = await getSupportedCurrencies();
    final byCode = {for (final c in list.currencies) c.code: c};
    emit(
      state.copyWith(
        currencyListStatus: CurrencyListStatus.ready,
        currencies: list.currencies,
        currencyListIsPartial: list.isPartial,
        // Upgrade the placeholder entities to the provider's names/symbols.
        source: byCode[state.source.code] ?? state.source,
        target: byCode[state.target.code] ?? state.target,
      ),
    );
  }

  /// Looks up the rate for the current pair. A result that arrives after
  /// the user picked another pair is dropped.
  Future<void> _loadRate(
    Emitter<CurrencyConverterState> emit, {
    bool forceRefresh = false,
  }) async {
    final base = state.source.code;
    final quote = state.target.code;
    bool stillCurrent() =>
        state.source.code == base && state.target.code == quote;

    final hadRate = _rateMatches(state.rate, base, quote);
    if (forceRefresh && hadRate) {
      emit(state.copyWith(isRefreshing: true, notice: null));
    } else {
      emit(
        state.copyWith(
          rateStatus: RateStatus.loading,
          rate: null,
          result: null,
          rateFailure: null,
          isRefreshing: forceRefresh,
        ),
      );
    }

    try {
      final lookup = await getExchangeRate(
        base,
        quote,
        forceRefresh: forceRefresh,
      );
      if (!stillCurrent()) return;
      emit(
        state.copyWith(
          rateStatus: lookup.fallbackReason?.isOffline ?? false
              ? RateStatus.offlineWithCachedRate
              : RateStatus.ready,
          rate: lookup,
          rateFailure: null,
          result: _convert(state.amount, lookup),
          isRefreshing: false,
          notice: forceRefresh
              ? (lookup.isFallback
                    ? ConverterNotice.refreshFailedUsingSaved
                    : ConverterNotice.rateUpdated)
              : null,
        ),
      );
    } on ExchangeRateException catch (e) {
      if (!stillCurrent()) return;
      _emitFailure(emit, e.failure, keepRate: forceRefresh && hadRate);
    } catch (e) {
      developer.log('[Converter] Rate lookup failed: $e', name: 'Converter');
      if (!stillCurrent()) return;
      _emitFailure(
        emit,
        ExchangeRateFailure.badResponse,
        keepRate: forceRefresh && hadRate,
      );
    }
  }

  /// A failed refresh never throws away the rate already on screen.
  void _emitFailure(
    Emitter<CurrencyConverterState> emit,
    ExchangeRateFailure failure, {
    required bool keepRate,
  }) {
    if (keepRate) {
      emit(
        state.copyWith(
          isRefreshing: false,
          notice: ConverterNotice.refreshFailedUsingSaved,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        rateStatus: RateStatus.error,
        rate: null,
        result: null,
        rateFailure: failure,
        isRefreshing: false,
      ),
    );
  }

  ExactDecimal? _convert(ExactDecimal? amount, RateLookup? lookup) {
    if (amount == null || lookup == null) return null;
    return convertAmount(
      amount: amount,
      rate: lookup.rate,
      targetDecimalDigits: CurrencyFormatter.decimalDigitsFor(
        lookup.rate.quoteCurrency,
      ),
    );
  }

  static bool _rateMatches(RateLookup? lookup, String base, String quote) =>
      lookup != null &&
      lookup.rate.baseCurrency == base &&
      lookup.rate.quoteCurrency == quote;

  void _persist() {
    final preferences = ConverterPreferences(
      sourceCode: state.source.code,
      targetCode: state.target.code,
      amountText: _lastValidAmountText,
    );
    savePreferences(preferences).catchError((Object e) {
      developer.log('[Converter] Could not save pair: $e', name: 'Converter');
    });
  }

  CurrencyEntity _entityFor(String code) {
    for (final c in state.currencies) {
      if (c.code == code) return c;
    }
    return _fallbackEntity(code);
  }

  /// Shown until the currency list arrives: the app's own metadata when the
  /// code is one of its settings currencies, otherwise just the code.
  static CurrencyEntity _fallbackEntity(String code) {
    for (final c in availableCurrencies) {
      if (c.code == code) return c;
    }
    return CurrencyEntity(
      code: code,
      symbol: CurrencyFormatter.resolveSymbol(code),
      name: code,
    );
  }
}
