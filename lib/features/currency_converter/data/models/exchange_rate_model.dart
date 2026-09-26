import '../../../../core/currency/exact_decimal.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/exchange_rate.dart';

/// Maps exchange rates between the Frankfurter JSON, the Drift cache row and
/// the domain [ExchangeRate].
abstract final class ExchangeRateModel {
  static final RegExp _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Parses `GET /v2/rate/{base}/{quote}`:
  /// `{"date": "2026-09-26", "base": "OMR", "quote": "INR", "rate": 249.33}`.
  ///
  /// Throws [FormatException] unless the body is a positive rate for exactly
  /// the requested pair on a valid date.
  static ExchangeRate fromJson(
    Object? json, {
    required String expectedBase,
    required String expectedQuote,
    required DateTime fetchedAt,
    required String provider,
  }) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Rate response is not an object');
    }
    final base = (json['base'] as Object?)?.toString().toUpperCase();
    final quote = (json['quote'] as Object?)?.toString().toUpperCase();
    if (base != expectedBase || quote != expectedQuote) {
      throw FormatException('Rate is for $base/$quote, not the requested pair');
    }
    final rawRate = json['rate'];
    if (rawRate is! num || !rawRate.isFinite || rawRate <= 0) {
      throw FormatException('Missing or invalid rate: $rawRate');
    }
    return ExchangeRate(
      baseCurrency: expectedBase,
      quoteCurrency: expectedQuote,
      rate: ExactDecimal.fromNum(rawRate),
      rateDate: parseRateDate(json['date']),
      fetchedAt: fetchedAt,
      provider: provider,
    );
  }

  /// Parses a `yyyy-MM-dd` reference day into a UTC midnight.
  static DateTime parseRateDate(Object? value) {
    final text = value?.toString() ?? '';
    final parsed = _isoDate.hasMatch(text)
        ? DateTime.tryParse('${text}T00:00:00Z')
        : null;
    if (parsed == null) throw FormatException('Invalid rate date', text);
    return parsed;
  }

  /// `yyyy-MM-dd` for a UTC reference day.
  static String formatRateDate(DateTime date) {
    final utc = date.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-'
        '${two(utc.day)}';
  }

  static ExchangeRatesCompanion toCompanion(ExchangeRate rate) {
    return ExchangeRatesCompanion.insert(
      id: rate.id,
      baseCurrency: rate.baseCurrency,
      quoteCurrency: rate.quoteCurrency,
      rate: rate.rate.toString(),
      rateDate: formatRateDate(rate.rateDate),
      fetchedAt: rate.fetchedAt,
      provider: rate.provider,
    );
  }

  /// Returns `null` for a row that no longer parses (never expected, but a
  /// corrupt cache entry must behave like a cache miss, not a crash).
  static ExchangeRate? fromRow(ExchangeRateRow row) {
    final rate = ExactDecimal.tryParse(row.rate);
    if (rate == null || rate <= ExactDecimal.zero) return null;
    try {
      return ExchangeRate(
        baseCurrency: row.baseCurrency,
        quoteCurrency: row.quoteCurrency,
        rate: rate,
        rateDate: parseRateDate(row.rateDate),
        fetchedAt: row.fetchedAt,
        provider: row.provider,
      );
    } on FormatException {
      return null;
    }
  }
}
