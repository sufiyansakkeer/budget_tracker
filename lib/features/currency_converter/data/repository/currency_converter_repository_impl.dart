import 'dart:developer' as developer;

import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/currency/exact_decimal.dart';
import '../../../settings/domain/entities/currency_entity.dart';
import '../../domain/entities/converter_preferences.dart';
import '../../domain/entities/exchange_rate.dart';
import '../../domain/entities/exchange_rate_failure.dart';
import '../../domain/entities/rate_lookup.dart';
import '../../domain/repository/currency_converter_repository.dart';
import '../../domain/services/exchange_rate_freshness_policy.dart';
import '../datasources/currency_local_datasource.dart';
import '../datasources/currency_remote_datasource.dart';
import '../models/currency_model.dart';

/// Cache-first exchange rates:
///
/// ```text
/// request pair → cached rate (direct, or 1/x of the reverse) fresh? → use it
///                              └ no → fetch → save → use it
///                                        └ fails → newest cached rate
///                                                  └ none → ExchangeRateException
/// ```
class CurrencyConverterRepositoryImpl implements CurrencyConverterRepository {
  final CurrencyRemoteDataSource remoteDataSource;
  final CurrencyLocalDataSource localDataSource;
  final ExchangeRateFreshnessPolicy freshnessPolicy;
  final DateTime Function() _clock;

  /// How long the supported-currency list is served from the cache before
  /// it is fetched again. Currencies change rarely.
  final Duration currencyListMaxAge;

  /// Concurrent lookups of the same pair share one request.
  final Map<String, Future<RateLookup>> _inFlight = {};

  CurrencyConverterRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    this.freshnessPolicy = const ExchangeRateFreshnessPolicy(),
    this.currencyListMaxAge = const Duration(days: 7),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  // ── Rates ────────────────────────────────────────────────────────────────

  @override
  Future<RateLookup> getRate(
    String base,
    String quote, {
    bool forceRefresh = false,
  }) {
    final from = base.toUpperCase();
    final to = quote.toUpperCase();
    if (from == to) return Future.value(_identity(from));
    final key = '${ExchangeRate.pairId(from, to)}|$forceRefresh';
    return _inFlight.putIfAbsent(
      key,
      () => _lookup(
        from,
        to,
        forceRefresh: forceRefresh,
      ).whenComplete(() {
        // Block body on purpose: `remove` returns this very future, and
        // whenComplete would wait on a returned future — i.e. on itself.
        _inFlight.remove(key);
      }),
    );
  }

  Future<RateLookup> _lookup(
    String base,
    String quote, {
    required bool forceRefresh,
  }) async {
    final cached = await _cachedCandidates(base, quote);

    if (!forceRefresh) {
      final now = _clock();
      final fresh = cached
          .where((c) => freshnessPolicy.isFresh(c.rate, now))
          .toList();
      if (fresh.isNotEmpty) return _best(fresh);
    }

    try {
      return await _fetch(
        base,
        quote,
        preferReverse: cached.any((c) => c.derived),
      );
    } on CurrencyApiException catch (e) {
      return _fallback(cached, e.failure);
    } catch (e) {
      developer.log(
        '[Converter] Unexpected fetch error: $e',
        name: 'Converter',
      );
      return _fallback(cached, ExchangeRateFailure.badResponse);
    }
  }

  /// Fetches and caches a rate for `base → quote`.
  ///
  /// When the pair is known to be the provider's low-precision direction
  /// (a strong reverse rate is cached), the reverse is fetched instead and
  /// inverted: that refreshes the stored rate the derivation depends on and
  /// keeps full precision (1 / 249.33 rather than the provider's 0.00401).
  Future<RateLookup> _fetch(
    String base,
    String quote, {
    required bool preferReverse,
  }) async {
    if (preferReverse) {
      final reverse = await remoteDataSource.fetchRate(quote, base);
      await _save(reverse);
      if (reverse.isStrongDirection) {
        return RateLookup(
          rate: reverse.inverted(),
          origin: RateOrigin.online,
          derived: true,
        );
      }
      // The rate crossed 1 since it was cached; the requested direction is
      // now the precise one.
    }
    final rate = await remoteDataSource.fetchRate(base, quote);
    await _save(rate);
    return RateLookup(rate: rate, origin: RateOrigin.online);
  }

  Future<void> _save(ExchangeRate rate) async {
    try {
      await localDataSource.saveRate(rate);
    } catch (e) {
      // The fetched rate is still valid for this conversion; the next
      // lookup will simply fetch again.
      developer.log('[Converter] Could not cache rate: $e', name: 'Converter');
    }
  }

  RateLookup _fallback(List<RateLookup> cached, ExchangeRateFailure failure) {
    if (cached.isEmpty) throw ExchangeRateException(failure);
    final best = _best(cached);
    return RateLookup(
      rate: best.rate,
      origin: RateOrigin.cached,
      derived: best.derived,
      fallbackReason: failure,
    );
  }

  /// Cached rates usable for `base → quote`: the direct pair, plus the
  /// inverse of the reverse pair when that one is precise enough to invert.
  Future<List<RateLookup>> _cachedCandidates(String base, String quote) async {
    try {
      final direct = await localDataSource.getRate(base, quote);
      final reverse = await localDataSource.getRate(quote, base);
      return [
        if (direct != null) RateLookup(rate: direct, origin: RateOrigin.cached),
        if (reverse != null && reverse.isStrongDirection)
          RateLookup(
            rate: reverse.inverted(),
            origin: RateOrigin.cached,
            derived: true,
          ),
      ];
    } catch (e) {
      developer.log(
        '[Converter] Could not read rate cache: $e',
        name: 'Converter',
      );
      return const [];
    }
  }

  /// Newest reference day first; on a tie the more precise candidate
  /// (strong direct, then derived from strong, then weak direct), then the
  /// most recently fetched.
  RateLookup _best(List<RateLookup> candidates) {
    int precisionRank(RateLookup c) =>
        c.derived ? 1 : (c.rate.isStrongDirection ? 0 : 2);
    final sorted = [...candidates]
      ..sort((a, b) {
        final byDate = b.rate.rateDate.compareTo(a.rate.rateDate);
        if (byDate != 0) return byDate;
        final byPrecision = precisionRank(a).compareTo(precisionRank(b));
        if (byPrecision != 0) return byPrecision;
        return b.rate.fetchedAt.compareTo(a.rate.fetchedAt);
      });
    return sorted.first;
  }

  RateLookup _identity(String code) {
    final now = _clock();
    final utc = now.toUtc();
    return RateLookup(
      rate: ExchangeRate(
        baseCurrency: code,
        quoteCurrency: code,
        rate: ExactDecimal.one,
        rateDate: DateTime.utc(utc.year, utc.month, utc.day),
        fetchedAt: now,
        provider: 'identity',
      ),
      origin: RateOrigin.identity,
    );
  }

  // ── Currencies ───────────────────────────────────────────────────────────

  @override
  Future<CurrencyList> getCurrencies() async {
    CachedCurrencyList? cached;
    try {
      cached = await localDataSource.getCurrencies();
    } catch (e) {
      developer.log(
        '[Converter] Could not read currency cache: $e',
        name: 'Converter',
      );
    }

    if (cached != null) {
      final age = _clock().difference(cached.fetchedAt);
      if (!age.isNegative && age < currencyListMaxAge) {
        return CurrencyList(currencies: _toEntities(cached.currencies));
      }
    }

    try {
      final fetched = await remoteDataSource.fetchCurrencies();
      try {
        await localDataSource.saveCurrencies(fetched, _clock());
      } catch (e) {
        developer.log(
          '[Converter] Could not cache currencies: $e',
          name: 'Converter',
        );
      }
      return CurrencyList(currencies: _toEntities(fetched));
    } catch (e) {
      if (cached != null) {
        return CurrencyList(currencies: _toEntities(cached.currencies));
      }
      // First launch while offline: the app's own currencies still work
      // for any pair whose rate is cached or fetchable later.
      return CurrencyList(
        currencies: [...availableCurrencies]
          ..sort((a, b) => a.code.compareTo(b.code)),
        isPartial: true,
      );
    }
  }

  /// The app's settings currencies keep their familiar names ("US Dollar");
  /// every symbol goes through [CurrencyFormatter.resolveSymbol].
  static List<CurrencyEntity> _toEntities(List<CurrencyModel> models) {
    final appNames = {for (final c in availableCurrencies) c.code: c.name};
    return [
      for (final m in models)
        CurrencyEntity(
          code: m.code,
          symbol: CurrencyFormatter.resolveSymbol(
            m.code,
            providerSymbol: m.symbol,
          ),
          name: appNames[m.code] ?? m.name,
        ),
    ]..sort((a, b) => a.code.compareTo(b.code));
  }

  // ── Preferences ──────────────────────────────────────────────────────────

  @override
  Future<ConverterPreferences> loadPreferences() async {
    try {
      return await localDataSource.getPreferences() ??
          ConverterPreferences.defaults;
    } catch (_) {
      return ConverterPreferences.defaults;
    }
  }

  @override
  Future<void> savePreferences(ConverterPreferences preferences) =>
      localDataSource.savePreferences(preferences);
}
