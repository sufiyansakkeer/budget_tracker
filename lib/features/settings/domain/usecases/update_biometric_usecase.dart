import '../entities/settings_failure.dart';
import '../repository/settings_repository.dart';

/// PERSISTS the biometric lock preference.
class UpdateBiometricUseCase {
  final SettingsRepository repository;

  UpdateBiometricUseCase({required this.repository});

  Future<SettingsResult<void>> call(bool enabled) async {
    try {
      await repository.setBiometricEnabled(enabled);
      return const SettingsSuccess(null);
    } catch (e) {
      return SettingsError(
        SettingsFailure(
          type: SettingsErrorType.saveFailure,
          message: 'Failed to save biometric preference: ${e.toString()}',
        ),
      );
    }
  }
}
