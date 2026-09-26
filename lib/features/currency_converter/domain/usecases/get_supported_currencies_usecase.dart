import '../repository/currency_converter_repository.dart';

/// Loads the currencies the converter can offer.
class GetSupportedCurrenciesUseCase {
  final CurrencyConverterRepository repository;

  const GetSupportedCurrenciesUseCase({required this.repository});

  Future<CurrencyList> call() => repository.getCurrencies();
}
