import 'package:equatable/equatable.dart';

/// A selectable currency with code, symbol and display name.
class CurrencyEntity extends Equatable {
  final String code;
  final String symbol;
  final String name;

  const CurrencyEntity({
    required this.code,
    required this.symbol,
    required this.name,
  });

  @override
  List<Object?> get props => [code, symbol, name];
}

/// The list of currencies supported by the app.
const List<CurrencyEntity> availableCurrencies = [
  CurrencyEntity(code: 'INR', symbol: '₹', name: 'Indian Rupee'),
  CurrencyEntity(code: 'USD', symbol: r'$', name: 'US Dollar'),
  CurrencyEntity(code: 'EUR', symbol: '€', name: 'Euro'),
  CurrencyEntity(code: 'AED', symbol: 'د.إ', name: 'UAE Dirham'),
  CurrencyEntity(code: 'OMR', symbol: 'ر.ع.', name: 'Omani Rial'),
  CurrencyEntity(code: 'GBP', symbol: '£', name: 'British Pound'),
  CurrencyEntity(code: 'CAD', symbol: r'C$', name: 'Canadian Dollar'),
  CurrencyEntity(code: 'AUD', symbol: r'A$', name: 'Australian Dollar'),
  CurrencyEntity(code: 'JPY', symbol: '¥', name: 'Japanese Yen'),
  CurrencyEntity(code: 'SGD', symbol: r'S$', name: 'Singapore Dollar'),
];

/// Finds a currency by code, defaulting to INR.
CurrencyEntity currencyByCode(String? code) {
  return availableCurrencies.firstWhere(
    (c) => c.code == code,
    orElse: () => availableCurrencies.first,
  );
}
