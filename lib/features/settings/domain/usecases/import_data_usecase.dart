import '../entities/settings_failure.dart';
import '../services/import_service.dart';

/// Imports data from a CSV or JSON file.
class ImportDataUseCase {
  final ImportService importService;

  ImportDataUseCase({required this.importService});

  Future<SettingsResult<int>> call(String path, {required bool json}) async {
    try {
      final count = json
          ? await importService.importJson(path)
          : await importService.importCsv(path);
      return SettingsSuccess(count);
    } on FormatException catch (e) {
      return SettingsError(
        SettingsFailure(
          type: SettingsErrorType.invalidData,
          message: e.message,
        ),
      );
    } catch (e) {
      return SettingsError(
        SettingsFailure(
          type: SettingsErrorType.importFailure,
          message: 'Failed to import data: ${e.toString()}',
        ),
      );
    }
  }
}
