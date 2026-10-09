import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_list.dart';

/// The two file formats Settings can export and import.
enum DataFormat { csv, json }

/// A sheet offering the file formats for an export or an import, each
/// explained in a sentence or two, that returns the one picked.
class DataFormatSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final Map<DataFormat, ({String title, String detail})> options;

  const DataFormatSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.options,
  });

  static const _csvTitle = 'Spreadsheet (CSV)';
  static const _jsonTitle = 'Data file (JSON)';

  /// Asks which format to export in.
  static Future<DataFormat?> showExport(BuildContext context) =>
      AppBottomSheet.show<DataFormat>(
        context: context,
        builder: (_) => const DataFormatSheet(
          title: 'Export',
          subtitle: 'Creates a file to share, keep or open in another app.',
          options: {
            DataFormat.csv: (
              title: _csvTitle,
              detail:
                  'Your expenses, one row each, with date, time, amount, '
                  'category, budget and note. Opens in Excel, Numbers or '
                  'Google Sheets.',
            ),
            DataFormat.json: (
              title: _jsonTitle,
              detail:
                  'Budgets, categories, expenses and settings in one '
                  'structured file, for other apps or to import into '
                  'Monivo later.',
            ),
          },
        ),
      );

  /// Asks which format to import from.
  static Future<DataFormat?> showImport(BuildContext context) =>
      AppBottomSheet.show<DataFormat>(
        context: context,
        builder: (_) => const DataFormatSheet(
          title: 'Import',
          subtitle:
              'Records from the file are merged into what you already have.',
          options: {
            DataFormat.csv: (
              title: _csvTitle,
              detail:
                  'Needs a header row naming the date, amount and category '
                  'columns, in any order. A Monivo CSV export works as it '
                  "is. Rows that can't be read are skipped.",
            ),
            DataFormat.json: (
              title: _jsonTitle,
              detail:
                  'A JSON file exported from Monivo. Records it shares with '
                  'this device are updated; the rest are added.',
            ),
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSheetHeader(title: title, subtitle: subtitle),
          Padding(
            // Lined up with the sheet's title; the sheet is the surface.
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: AppGroupedList(
              dividerIndent: AppSizes.avatarSm + AppSpacing.smd,
              children: [
                for (final MapEntry(key: format, value: option)
                    in options.entries)
                  AppListRow(
                    key: Key('dataFormat_${format.name}'),
                    leading: IconTile(
                      icon: format == DataFormat.csv
                          ? Icons.table_chart_outlined
                          : Icons.data_object_rounded,
                      color: theme.colorScheme.primary,
                      size: AppSizes.avatarSm,
                    ),
                    title: option.title,
                    subtitleWidget: Text(option.detail, style: muted),
                    semanticLabel: '${option.title}. ${option.detail}',
                    trailing: Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onTap: () => Navigator.of(context).pop(format),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
