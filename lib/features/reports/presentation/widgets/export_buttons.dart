import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/entities/report_data.dart';
import '../../domain/entities/report_failure.dart';
import '../../domain/usecases/export_csv_usecase.dart';
import '../../domain/usecases/export_pdf_usecase.dart';

/// Export buttons for CSV and PDF reports.
class ExportButtons extends StatelessWidget {
  final ReportData data;
  final ExportCsvUseCase exportCsvUseCase;
  final ExportPdfUseCase exportPdfUseCase;

  /// Callback to surface export success/error messages.
  final void Function(String message, bool isError)? onResult;

  const ExportButtons({
    super.key,
    required this.data,
    required this.exportCsvUseCase,
    required this.exportPdfUseCase,
    this.onResult,
  });

  Future<void> _export(BuildContext context, {required bool isCsv}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = isCsv
          ? await exportCsvUseCase(data)
          : await exportPdfUseCase(data);

      switch (result) {
        case ReportSuccess():
          onResult?.call((result as ReportSuccess).data as String, false);
          messenger.showSnackBar(
            SnackBar(
              content: Text('${isCsv ? 'CSV' : 'PDF'} report exported.'),
            ),
          );
        case ReportError(:final failure):
          onResult?.call(failure.message, true);
          messenger.showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _export(context, isCsv: true),
            icon: const Icon(Icons.table_chart),
            label: const Text('CSV'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _export(context, isCsv: false),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('PDF'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
