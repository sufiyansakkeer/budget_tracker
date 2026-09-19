import 'package:flutter/material.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/currency/currency_formatter.dart';
import '../../../../../core/domain/entities/budget_entity.dart';
import '../../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../../core/widgets/app_header.dart';
import '../../widgets/category_visuals.dart';

/// Bottom sheet for selecting multiple budgets for the combined expense view.
///
/// Returns a [List<String>] of selected budget IDs when the user taps Apply,
/// or `null` if cancelled.
class BudgetSelectionSheet extends StatefulWidget {
  final List<BudgetEntity> allBudgets;
  final List<String> initiallySelected;

  const BudgetSelectionSheet({
    super.key,
    required this.allBudgets,
    required this.initiallySelected,
  });

  /// Shows the bottom sheet and returns the selected budget IDs or null.
  static Future<List<String>?> show({
    required BuildContext context,
    required List<BudgetEntity> allBudgets,
    required List<String> initiallySelected,
  }) {
    return AppBottomSheet.show<List<String>>(
      context: context,
      builder: (_) => BudgetSelectionSheet(
        allBudgets: allBudgets,
        initiallySelected: initiallySelected,
      ),
    );
  }

  @override
  State<BudgetSelectionSheet> createState() => _BudgetSelectionSheetState();
}

class _BudgetSelectionSheetState extends State<BudgetSelectionSheet> {
  late Set<String> _selected = Set<String>.from(widget.initiallySelected);

  bool get _allSelected =>
      widget.allBudgets.isNotEmpty &&
      _selected.length == widget.allBudgets.length;

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _apply() {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Select at least one budget')),
        );
      return;
    }
    Navigator.of(context).pop(_selected.toList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSheetHeader(
            title: 'Select Budgets',
            subtitle:
                '${_selected.length} of ${widget.allBudgets.length} selected · '
                'each expense keeps its own budget',
            trailing: TextButton(
              onPressed: widget.allBudgets.isEmpty
                  ? null
                  : () => setState(() {
                      _selected = _allSelected
                          ? <String>{}
                          : widget.allBudgets.map((b) => b.id).toSet();
                    }),
              child: Text(_allSelected ? 'Clear All' : 'Select All'),
            ),
          ),
          Flexible(
            child: widget.allBudgets.isEmpty
                ? Padding(
                    padding: AppSpacing.paddingLg,
                    child: Text(
                      'No budgets available to combine.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    itemCount: widget.allBudgets.length,
                    itemBuilder: (context, index) {
                      final budget = widget.allBudgets[index];
                      return _BudgetTile(
                        budget: budget,
                        isSelected: _selected.contains(budget.id),
                        onTap: () => _toggle(budget.id),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: FilledButton(onPressed: _apply, child: const Text('Apply')),
          ),
        ],
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  final BudgetEntity budget;
  final bool isSelected;
  final VoidCallback onTap;

  const _BudgetTile({
    required this.budget,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = budget.color == null || budget.color!.isEmpty
        ? theme.colorScheme.primary
        : CategoryVisuals.adaptiveColor(context, budget.color!);
    final remaining = CurrencyFormatter.format(
      budget.remainingAmount,
      code: budget.currency,
      decimalDigits: 0,
    );
    final total = CurrencyFormatter.format(
      budget.monthlyAmount,
      code: budget.currency,
      decimalDigits: 0,
    );

    return CheckboxListTile(
      value: isSelected,
      onChanged: (_) => onTap(),
      controlAffinity: ListTileControlAffinity.leading,
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.4,
      ),
      secondary: Container(
        width: AppSizes.progressThin,
        height: AppSizes.avatarSm,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: AppSpacing.borderRadiusXs,
        ),
      ),
      title: Text(
        budget.name,
        style: theme.textTheme.titleSmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${formatShortDateRange(budget.startDate, budget.endDate)} · '
        '$remaining left of $total',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
