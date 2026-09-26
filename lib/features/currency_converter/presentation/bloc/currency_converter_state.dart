import 'package:equatable/equatable.dart';

import '../../../../core/currency/exact_decimal.dart';
import '../../../settings/domain/entities/currency_entity.dart';
import '../../domain/entities/exchange_rate_failure.dart';
import '../../domain/entities/rate_lookup.dart';
import '../../domain/validators/amount_input_validator.dart';

enum CurrencyListStatus { initial, loading, ready }

/// Rate lifecycle for the current pair.
///
/// There is deliberately no "converting" status: conversion is a local,
/// synchronous multiplication, so the result is part of the same state
/// update as the amount and the screen never waits on it.
enum RateStatus {
  initial,

  /// Looking up a rate for a newly selected pair.
  loading,

  /// A rate is loaded (online, fresh from cache, or a cached fallback after
  /// a provider error — see [RateLookup.fallbackReason]).
  ready,

  /// The device is offline and the rate is a saved one.
  offlineWithCachedRate,

  /// No rate: the lookup failed and nothing was cached ([rateFailure]).
  error,
}

/// One-shot feedback shown as a snackbar, cleared with
/// `CurrencyConverterNoticeCleared`.
enum ConverterNotice { rateUpdated, refreshFailedUsingSaved }

class CurrencyConverterState extends Equatable {
  final CurrencyListStatus currencyListStatus;

  /// Sorted by code. Empty until the first load finishes.
  final List<CurrencyEntity> currencies;

  /// Only the app's built-in currencies are available (first launch offline).
  final bool currencyListIsPartial;

  final CurrencyEntity source;
  final CurrencyEntity target;

  /// Raw text of the amount field.
  final String amountText;

  /// Parsed [amountText], `null` while it is invalid.
  final ExactDecimal? amount;
  final AmountInputError? amountError;

  final RateStatus rateStatus;

  /// Rate for exactly `source → target`, or `null`.
  final RateLookup? rate;
  final ExchangeRateFailure? rateFailure;

  /// `amount × rate`, rounded to the target currency's decimals.
  final ExactDecimal? result;

  /// A "Refresh rate" request is in flight; [rate] stays on screen.
  final bool isRefreshing;

  /// True once the saved pair and amount have been restored.
  final bool isRestored;

  /// Incremented on every swap so the swap button can turn.
  final int swapCount;

  final ConverterNotice? notice;

  const CurrencyConverterState({
    this.currencyListStatus = CurrencyListStatus.initial,
    this.currencies = const [],
    this.currencyListIsPartial = false,
    required this.source,
    required this.target,
    this.amountText = '',
    this.amount,
    this.amountError,
    this.rateStatus = RateStatus.initial,
    this.rate,
    this.rateFailure,
    this.result,
    this.isRefreshing = false,
    this.isRestored = false,
    this.swapCount = 0,
    this.notice,
  });

  bool get hasRate => rate != null;

  static const Object _unset = Object();

  CurrencyConverterState copyWith({
    CurrencyListStatus? currencyListStatus,
    List<CurrencyEntity>? currencies,
    bool? currencyListIsPartial,
    CurrencyEntity? source,
    CurrencyEntity? target,
    String? amountText,
    Object? amount = _unset,
    Object? amountError = _unset,
    RateStatus? rateStatus,
    Object? rate = _unset,
    Object? rateFailure = _unset,
    Object? result = _unset,
    bool? isRefreshing,
    bool? isRestored,
    int? swapCount,
    Object? notice = _unset,
  }) {
    return CurrencyConverterState(
      currencyListStatus: currencyListStatus ?? this.currencyListStatus,
      currencies: currencies ?? this.currencies,
      currencyListIsPartial:
          currencyListIsPartial ?? this.currencyListIsPartial,
      source: source ?? this.source,
      target: target ?? this.target,
      amountText: amountText ?? this.amountText,
      amount: identical(amount, _unset) ? this.amount : amount as ExactDecimal?,
      amountError: identical(amountError, _unset)
          ? this.amountError
          : amountError as AmountInputError?,
      rateStatus: rateStatus ?? this.rateStatus,
      rate: identical(rate, _unset) ? this.rate : rate as RateLookup?,
      rateFailure: identical(rateFailure, _unset)
          ? this.rateFailure
          : rateFailure as ExchangeRateFailure?,
      result: identical(result, _unset) ? this.result : result as ExactDecimal?,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isRestored: isRestored ?? this.isRestored,
      swapCount: swapCount ?? this.swapCount,
      notice: identical(notice, _unset)
          ? this.notice
          : notice as ConverterNotice?,
    );
  }

  @override
  List<Object?> get props => [
    currencyListStatus,
    currencies,
    currencyListIsPartial,
    source,
    target,
    amountText,
    amount,
    amountError,
    rateStatus,
    rate,
    rateFailure,
    result,
    isRefreshing,
    isRestored,
    swapCount,
    notice,
  ];
}
