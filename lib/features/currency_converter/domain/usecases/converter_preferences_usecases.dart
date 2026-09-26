import '../entities/converter_preferences.dart';
import '../repository/currency_converter_repository.dart';

/// Restores the last currency pair and amount.
class LoadConverterPreferencesUseCase {
  final CurrencyConverterRepository repository;

  const LoadConverterPreferencesUseCase({required this.repository});

  Future<ConverterPreferences> call() => repository.loadPreferences();
}

/// Remembers the current currency pair and amount.
class SaveConverterPreferencesUseCase {
  final CurrencyConverterRepository repository;

  const SaveConverterPreferencesUseCase({required this.repository});

  Future<void> call(ConverterPreferences preferences) =>
      repository.savePreferences(preferences);
}
