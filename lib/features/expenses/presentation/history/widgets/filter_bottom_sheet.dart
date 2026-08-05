import 'package:flutter/material.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../domain/entities/expense_category.dart';
import '../../../domain/entities/expense_history_filter.dart';

/// Modern Material 3 bottom sheet for applying expense filters.
///
/// Returns the resulting [ExpenseHistoryFilter] when the user taps Apply, or
/// null if the sheet is dismissed/cancelled.
class FilterBottomSheet extends StatefulWidget {
  final ExpenseHistoryFilter current;
  final List<ExpenseCategory> categories;

  const FilterBottomSheet({
    super.key,
    required this.current,
    required this.categories,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late String? _categoryId;
  late DateTime? _dateFrom;
  late DateTime? _dateTo;
  late TextEditingController _minAmount;
  late TextEditingController _maxAmount;
  late List<String> _tags;
  late bool _receiptOnly;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.current.categoryId;
    _dateFrom = widget.current.dateFrom;
    _dateTo = widget.current.dateTo;
    _minAmount = TextEditingController(
      text: widget.current.minAmount?.toString(),
    );
    _maxAmount = TextEditingController(
      text: widget.current.maxAmount?.toString(),
    );
    _tags = List.of(widget.current.tags);
    _receiptOnly = widget.current.receiptOnly;
  }

  @override
  void dispose() {
    _minAmount.dispose();
    _maxAmount.dispose();
    super.dispose();
  }

  void _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_dateFrom ?? now) : (_dateTo ?? now),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
    }
  }

  void _addTag() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add tag'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. lunch'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final tag = controller.text.trim();
              if (tag.isNotEmpty && !_tags.contains(tag)) {
                setState(() => _tags.add(tag));
              }
              controller.dispose();
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Category
            Text('Category', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _categoryId == null,
                  onSelected: (_) => setState(() => _categoryId = null),
                ),
                ...widget.categories.map(
                  (category) => ChoiceChip(
                    key: Key('filter_category_${category.id}'),
                    label: Text(category.name),
                    selected: _categoryId == category.id,
                    onSelected: (_) =>
                        setState(() => _categoryId = category.id),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Date range
            Text('Date Range', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(isFrom: true),
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _dateFrom == null
                          ? 'From'
                          : '${_dateFrom!.day}/${_dateFrom!.month}/${_dateFrom!.year}',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(isFrom: false),
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _dateTo == null
                          ? 'To'
                          : '${_dateTo!.day}/${_dateTo!.month}/${_dateTo!.year}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Amount range
            Text('Amount Range', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minAmount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Min'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: _maxAmount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Max'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Tags
            Text('Tags', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._tags.map(
                  (tag) => Chip(
                    label: Text(tag),
                    onDeleted: () =>
                        setState(() => _tags.removeWhere((t) => t == tag)),
                  ),
                ),
                ActionChip(
                  key: const Key('filterAddTag'),
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Add tag'),
                  onPressed: _addTag,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Receipt only
            SwitchListTile(
              key: const Key('filterReceiptOnly'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Receipt attached only'),
              value: _receiptOnly,
              onChanged: (value) => setState(() => _receiptOnly = value),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    key: const Key('applyFilters'),
                    onPressed: () {
                      final filter = ExpenseHistoryFilter(
                        categoryId: _categoryId,
                        dateFrom: _dateFrom,
                        dateTo: _dateTo,
                        minAmount: double.tryParse(_minAmount.text),
                        maxAmount: double.tryParse(_maxAmount.text),
                        tags: _tags,
                        receiptOnly: _receiptOnly,
                      );
                      Navigator.pop(context, filter);
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper to show the filter bottom sheet and return the result.
Future<ExpenseHistoryFilter?> showFilterBottomSheet(
  BuildContext context, {
  required ExpenseHistoryFilter current,
  required List<ExpenseCategory> categories,
}) {
  return showModalBottomSheet<ExpenseHistoryFilter>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusLg),
      ),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: FilterBottomSheet(current: current, categories: categories),
    ),
  );
}
