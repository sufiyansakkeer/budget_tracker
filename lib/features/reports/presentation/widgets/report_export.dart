import 'package:flutter/material.dart';

import '../../domain/entities/report_data.dart';
import '../../domain/entities/report_failure.dart';
import '../../domain/usecases/export_csv_usecase.dart';
import '../../domain/usecases/export_pdf_usecase.dart';
import '../../../../core/errors/user_facing_error.dart';

/// Shares the report as CSV or PDF through the system sheet, from the
/// Reports menu, and says how it went.
abstract final class ReportExport {
  static Future<void> run(
    BuildContext context,
    ReportData data, {
    required bool csv,
    ExportCsvUseCase exportCsv = const ExportCsvUseCase(),
    ExportPdfUseCase exportPdf = const ExportPdfUseCase(),
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final kind = csv ? 'CSV' : 'PDF';
    void say(String message) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    try {
      final result = csv ? await exportCsv(data) : await exportPdf(data);
      switch (result) {
        case ReportSuccess():
          say('$kind report ready to share.');
        case ReportError(:final failure):
          say(
            userFacingError(
              failure.message,
              forPeople: false,
              fallback: "Couldn't export the $kind report. Try again.",
            ),
          );
      }
    } catch (_) {
      say("Couldn't export the $kind report. Try again.");
    }
  }
}
