import 'package:flutter/material.dart';

import '../../../../core/constants/app_copy.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/dates/date_range_format.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';

/// The app's one budget picker (UX-110): a sheet listing budgets, one row
/// each, for switching the active budget and for moving an expense.
///
/// Each caller keeps its own rules through parameters: [disabledReason]
/// lists a budget that can't be picked, greyed out, with the reason in
/// place of its dates (another currency, a period that misses the date, an
/// archived budget). Picking an enabled row closes the sheet with
/// [onPick]'s result; [onOpen] adds a details button that closes it with
/// its own. [footer] holds the sheet's other actions; they close the sheet
/// themselves, with its context.
abstract final class BudgetPickerSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    String? subtitle,
    required List<BudgetEntity> budgets,
    required T Function(BudgetEntity budget) onPick,
    String? selectedId,
    String? Function(BudgetEntity budget)? disabledReason,
    String Function(BudgetEntity budget)? describe,
    T Function(BudgetEntity budget)? onOpen,
    Key Function(BudgetEntity budget)? rowKey,
    String emptyText = 'You have no budgets yet.',
    List<Widget> Function(BuildContext sheetContext)? footer,
  }) => AppBottomSheet.show<T>(
    context: context,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final actions = footer?.call(sheetContext) ?? const <Widget>[];
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSheetHeader(title: title, subtitle: subtitle),
          if (budgets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Text(
                emptyText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                children: [
                  for (final budget in budgets)
                    BudgetPickerRow(
                      tileKey: rowKey?.call(budget),
                      budget: budget,
                      selected: budget.id == selectedId,
                      reason: disabledReason?.call(budget),
                      detail: (describe ?? BudgetPickerSheet.describe)(budget),
                      onPick: () =>
                          Navigator.of(sheetContext).pop(onPick(budget)),
                      onOpen: onOpen == null
                          ? null
                          : () =>
                                Navigator.of(sheetContext).pop(onOpen(budget)),
                    ),
                ],
              ),
            ),
          if (actions.isNotEmpty) ...[
            const Divider(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(child: actions[i]),
                  ],
                ],
              ),
            ),
          ] else
            const SizedBox(height: AppSpacing.sm),
        ],
      );
    },
  );

  /// A row's line under the name: its dates ("22 – 30 Sep"), the currency
  /// when [showCurrency], and when [today] is given whether it has not
  /// started, has ended or is archived.
  static String describe(
    BudgetEntity budget, {
    bool showCurrency = false,
    DateTime? today,
  }) => [
    AppDates.span(budget.startDate, budget.endDate),
    if (showCurrency) budget.currency,
    if (budget.isArchived)
      'Archived'
    else if (today != null && !budget.isActiveOn(today))
      today.isBefore(budget.startDate) ? AppTerms.notStarted : 'Ended',
  ].join(' · ');
}

/// One budget in [BudgetPickerSheet]: a radio mark, its name and [detail],
/// or why it can't be picked ([reason]) and greyed out.
class BudgetPickerRow extends StatelessWidget {
  final BudgetEntity budget;
  final bool selected;
  final String? reason;
  final String detail;
  final VoidCallback onPick;
  final VoidCallback? onOpen;

  /// The key of the [ListTile] itself, for finders that read it.
  final Key? tileKey;

  const BudgetPickerRow({
    super.key,
    this.tileKey,
    required this.budget,
    required this.selected,
    required this.reason,
    required this.detail,
    required this.onPick,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = reason == null;
    return ListTile(
      key: tileKey,
      enabled: enabled,
      selected: selected,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.5,
      ),
      leading: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_off_rounded,
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        budget.name,
        style: theme.textTheme.titleSmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(reason ?? detail),
      trailing: onOpen == null
          ? null
          : IconButton(
              tooltip: 'Budget details',
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: onOpen,
            ),
      onTap: enabled ? onPick : null,
    );
  }
}
