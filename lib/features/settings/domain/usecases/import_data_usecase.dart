import '../entities/import_report.dart';
import '../entities/settings_failure.dart';
import '../services/import_service.dart';

/// Imports data from a CSV or JSON file and reports what it added,
/// updated and skipped.
class ImportDataUseCase {
  final ImportService importService;

  ImportDataUseCase({required this.importService});

  Future<SettingsResult<ImportReport>> call(
    String path, {
    required bool json,
  }) async {
    try {
      final report = json
          ? await importService.importJson(path)
          : await importService.importCsv(path);
      return SettingsSuccess(report);
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
