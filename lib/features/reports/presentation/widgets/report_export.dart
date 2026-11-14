import 'package:flutter/material.dart';

import '../../../../core/widgets/app_snack.dart';
import '../../domain/entities/report_data.dart';
import '../../domain/entities/report_failure.dart';
import '../../domain/usecases/export_csv_usecase.dart';
import '../../domain/usecases/export_pdf_usecase.dart';
import '../../../../core/files/file_delivery_service.dart';
import '../../../../core/errors/user_facing_error.dart';

/// Shares the report as CSV or PDF through the system sheet, from the
/// Reports menu, and says how it went. [shareOrigin] is the menu button's
/// rect, where the sheet points from on iPad; [budgetName] is written into
/// the file.
///
/// Only an outcome the platform confirmed is called a success: a closed
/// sheet is "not shared", and one that can't say is "sent to the share
/// sheet", as Settings words it (UX-089).
abstract final class ReportExport {
  static Future<void> run(
    BuildContext context,
    ReportData data, {
    required bool csv,
    Rect? shareOrigin,
    String? budgetName,
    ExportCsvUseCase exportCsv = const ExportCsvUseCase(),
    ExportPdfUseCase exportPdf = const ExportPdfUseCase(),
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final kind = csv ? 'CSV' : 'PDF';
    void say(String message) => AppSnack.showOn(messenger, message);
    try {
      final result = csv
          ? await exportCsv(
              data,
              shareOrigin: shareOrigin,
              budgetName: budgetName,
            )
          : await exportPdf(
              data,
              shareOrigin: shareOrigin,
              budgetName: budgetName,
            );
      switch (result) {
        case ReportSuccess(:final data):
          say(switch (data) {
            FileDeliveryOutcome.shared => '$kind report shared.',
            FileDeliveryOutcome.saved => '$kind report saved.',
            FileDeliveryOutcome.handedOff =>
              '$kind report sent to the share sheet.',
            FileDeliveryOutcome.cancelled => '$kind report not shared.',
          });
        case ReportError(:final failure):
          say(
            userFacingError(
              failure.message,
              forPeople: false,
              fallback: "Couldn't export the $kind report. Try again.",
            ),
          );
      }
    } catch (e) {
      debugPrint('[error] Exporting the $kind report: $e');
      say("Couldn't export the $kind report. Try again.");
    }
  }
}
