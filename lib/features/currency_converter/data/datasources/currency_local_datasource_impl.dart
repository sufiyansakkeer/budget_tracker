import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/preference_keys.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/converter_preferences.dart';
import '../../domain/entities/exchange_rate.dart';
import '../models/currency_model.dart';
import '../models/exchange_rate_model.dart';
import 'currency_local_datasource.dart';

class CurrencyLocalDataSourceImpl implements CurrencyLocalDataSource {
  final AppDatabase database;
  final SharedPreferences sharedPreferences;

  CurrencyLocalDataSourceImpl({
    required this.database,
    required this.sharedPreferences,
  });

  @override
  Future<ExchangeRate?> getRate(String base, String quote) async {
    final id = ExchangeRate.pairId(base, quote);
    final row = await (database.select(
      database.exchangeRates,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    return row == null ? null : ExchangeRateModel.fromRow(row);
  }

  @override
  Future<void> saveRate(ExchangeRate rate) async {
    await database
        .into(database.exchangeRates)
        .insertOnConflictUpdate(ExchangeRateModel.toCompanion(rate));
  }

  @override
  Future<CachedCurrencyList?> getCurrencies() async {
    final rows = await (database.select(
      database.converterCurrencies,
    )..orderBy([(c) => OrderingTerm.asc(c.code)])).get();
    if (rows.isEmpty) return null;
    // Rows are written together, so the oldest stamp is the list's age.
    final fetchedAt = rows
        .map((r) => r.fetchedAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    return CachedCurrencyList(
      currencies: rows.map(CurrencyModel.fromRow).toList(),
      fetchedAt: fetchedAt,
    );
  }

  @override
  Future<void> saveCurrencies(
    List<CurrencyModel> currencies,
    DateTime fetchedAt,
  ) async {
    await database.transaction(() async {
      await database.delete(database.converterCurrencies).go();
      await database.batch((b) {
        b.insertAll(database.converterCurrencies, [
          for (final c in currencies) c.toCompanion(fetchedAt),
        ], mode: InsertMode.insertOrReplace);
      });
    });
  }

  @override
  Future<ConverterPreferences?> getPreferences() async {
    final source = sharedPreferences.getString(
      PreferenceKeys.converterSourceCurrency,
    );
    final target = sharedPreferences.getString(
      PreferenceKeys.converterTargetCurrency,
    );
    if (source == null || target == null) return null;
    return ConverterPreferences(
      sourceCode: source,
      targetCode: target,
      amountText:
          sharedPreferences.getString(PreferenceKeys.converterAmount) ??
          ConverterPreferences.defaults.amountText,
    );
  }

  @override
  Future<void> savePreferences(ConverterPreferences preferences) async {
    await Future.wait([
      sharedPreferences.setString(
        PreferenceKeys.converterSourceCurrency,
        preferences.sourceCode,
      ),
      sharedPreferences.setString(
        PreferenceKeys.converterTargetCurrency,
        preferences.targetCode,
      ),
      sharedPreferences.setString(
        PreferenceKeys.converterAmount,
        preferences.amountText,
      ),
    ]);
  }
}
