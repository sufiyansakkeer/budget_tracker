import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';

/// A supported currency as the provider describes it. The display symbol is
/// resolved later (see `CurrencyFormatter.resolveSymbol`), so the cache keeps
/// the provider's raw values.
class CurrencyModel {
  final String code;
  final String name;
  final String? symbol;

  const CurrencyModel({required this.code, required this.name, this.symbol});

  static final RegExp _isoCode = RegExp(r'^[A-Z]{3}$');

  /// Parses `GET /v2/currencies`, skipping entries without a usable ISO
  /// code. Throws [FormatException] when the body is not a list or holds no
  /// usable entry at all.
  static List<CurrencyModel> listFromJson(Object? json) {
    if (json is! List) {
      throw const FormatException('Currency response is not a list');
    }
    final byCode = <String, CurrencyModel>{};
    for (final item in json) {
      if (item is! Map<String, dynamic>) continue;
      final code = (item['iso_code'] as Object?)?.toString().toUpperCase();
      if (code == null || !_isoCode.hasMatch(code)) continue;
      final name = (item['name'] as Object?)?.toString().trim();
      final symbol = (item['symbol'] as Object?)?.toString().trim();
      byCode[code] = CurrencyModel(
        code: code,
        name: (name == null || name.isEmpty) ? code : name,
        symbol: (symbol == null || symbol.isEmpty) ? null : symbol,
      );
    }
    if (byCode.isEmpty) {
      throw const FormatException('Currency response has no currencies');
    }
    return byCode.values.toList()..sort((a, b) => a.code.compareTo(b.code));
  }

  factory CurrencyModel.fromRow(ConverterCurrencyRow row) =>
      CurrencyModel(code: row.code, name: row.name, symbol: row.symbol);

  ConverterCurrenciesCompanion toCompanion(DateTime fetchedAt) =>
      ConverterCurrenciesCompanion.insert(
        code: code,
        name: name,
        symbol: Value(symbol),
        fetchedAt: fetchedAt,
      );
}
