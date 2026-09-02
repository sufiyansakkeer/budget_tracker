import 'package:flutter/material.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/currency/currency_formatter.dart';
import '../../../../../core/domain/entities/budget_entity.dart';
import '../../../../../core/theme/app_colors_extension.dart';

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
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
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
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initiallySelected);
  }

  bool get _allSelected => _selected.length == widget.allBudgets.length;

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selected = widget.allBudgets.map((b) => b.id).toSet();
    });
  }

  void _clearAll() {
    setState(() {
      _selected.clear();
    });
  }

  void _apply() {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Select at least one budget'),
          backgroundColor: context.appColors.warning,
        ),
      );
      return;
    }
    Navigator.of(context).pop(_selected.toList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: EdgeInsets.only(top: AppSpacing.sm),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Budgets',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '${_selected.length} of ${widget.allBudgets.length} selected',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _allSelected ? _clearAll : _selectAll,
                    child: Text(_allSelected ? 'Clear All' : 'Select All'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Budget list
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                itemCount: widget.allBudgets.length,
                itemBuilder: (context, index) {
                  final budget = widget.allBudgets[index];
                  final isSelected = _selected.contains(budget.id);
                  return _BudgetTile(
                    budget: budget,
                    isSelected: isSelected,
                    onTap: () => _toggle(budget.id),
                  );
                },
              ),
            ),
            // Apply button
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: _apply, child: Text('Apply')),
                ),
              ),
            ),
          ],
        );
      },
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
    final spent = budget.monthlyAmount - budget.remainingAmount;

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: isSelected
            ? context.appColors.secondary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: AppSpacing.borderRadiusMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppSpacing.borderRadiusMd,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.smd,
            ),
            decoration: BoxDecoration(
              borderRadius: AppSpacing.borderRadiusMd,
              border: Border.all(
                color: isSelected
                    ? context.appColors.secondary
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onTap(),
                  activeColor: context.appColors.secondary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                SizedBox(width: AppSpacing.sm),
                // Budget color indicator
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        _parseColor(budget.color) ??
                        context.appColors.secondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        budget.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${CurrencyFormatter.format(budget.monthlyAmount, decimalDigits: 0)} budget',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      Text(
                        '${CurrencyFormatter.format(spent, decimalDigits: 0)} spent',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('FF');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return null;
    }
  }
}
