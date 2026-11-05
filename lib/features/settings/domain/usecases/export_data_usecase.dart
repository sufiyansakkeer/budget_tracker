import 'dart:ui' show Rect;

import '../entities/settings_failure.dart';
import '../services/export_service.dart';

/// Exports application data (CSV or JSON) and opens the share sheet.
class ExportDataUseCase {
  final ExportService exportService;

  ExportDataUseCase({required this.exportService});

  /// [shareOrigin] anchors the share sheet (see [ExportService]).
  Future<SettingsResult<String>> call({
    bool csv = true,
    Rect? shareOrigin,
  }) async {
    try {
      final result = csv
          ? await exportService.exportCsv(shareOrigin: shareOrigin)
          : await exportService.exportJson(shareOrigin: shareOrigin);
      return SettingsSuccess(result.message);
    } catch (e) {
      return SettingsError(
        SettingsFailure(
          type: SettingsErrorType.exportFailure,
          message: 'Failed to export data: ${e.toString()}',
        ),
      );
    }
  }
}
