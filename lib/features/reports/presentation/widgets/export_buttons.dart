import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../domain/entities/report_data.dart';
import '../../domain/entities/report_failure.dart';
import '../../domain/usecases/export_csv_usecase.dart';
import '../../domain/usecases/export_pdf_usecase.dart';

/// Export buttons for CSV and PDF reports, with a busy state so a slow PDF
/// export can't be triggered twice.
class ExportButtons extends StatefulWidget {
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

  @override
  State<ExportButtons> createState() => _ExportButtonsState();
}

class _ExportButtonsState extends State<ExportButtons> {
  bool _busyCsv = false;
  bool _busyPdf = false;

  bool get _busy => _busyCsv || _busyPdf;

  Future<void> _export({required bool isCsv}) async {
    if (_busy) return;
    setState(() => isCsv ? _busyCsv = true : _busyPdf = true);
    final messenger = ScaffoldMessenger.of(context);
    final kind = isCsv ? 'CSV' : 'PDF';
    try {
      final result = isCsv
          ? await widget.exportCsvUseCase(widget.data)
          : await widget.exportPdfUseCase(widget.data);

      switch (result) {
        case ReportSuccess(:final data):
          widget.onResult?.call(data.toString(), false);
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text('$kind report ready to share.')),
            );
        case ReportError(:final failure):
          widget.onResult?.call(failure.message, true);
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text("Couldn't export the $kind report.")),
        );
    } finally {
      if (mounted) {
        setState(() => isCsv ? _busyCsv = false : _busyPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _export(isCsv: true),
            icon: _busyCsv
                ? const _Spinner()
                : const Icon(Icons.table_chart_outlined),
            label: const Text('Export CSV'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: _busy ? null : () => _export(isCsv: false),
            icon: _busyPdf
                ? const _Spinner()
                : const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Export PDF'),
          ),
        ),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: AppSizes.iconSm + 2,
      height: AppSizes.iconSm + 2,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
