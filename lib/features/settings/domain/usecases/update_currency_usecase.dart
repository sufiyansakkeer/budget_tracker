import '../entities/settings_failure.dart';
import '../repository/settings_repository.dart';

/// Updates the application currency code.
class UpdateCurrencyUseCase {
  final SettingsRepository repository;

  UpdateCurrencyUseCase({required this.repository});

  Future<SettingsResult<void>> call(String code, String symbol) async {
    if (code.isEmpty) {
      return const SettingsError(
        SettingsFailure(
          type: SettingsErrorType.invalidData,
          message: 'Currency code cannot be empty.',
        ),
      );
    }
    try {
      await repository.setCurrency(code, symbol);
      return const SettingsSuccess(null);
    } catch (e) {
      return SettingsError(
        SettingsFailure(
          type: SettingsErrorType.saveFailure,
          message: 'Failed to save currency preference: ${e.toString()}',
        ),
      );
    }
  }
}
