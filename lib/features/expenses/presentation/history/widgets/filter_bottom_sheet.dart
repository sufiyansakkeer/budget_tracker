import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/widgets/app_bottom_sheet.dart';
import '../../../domain/entities/expense_category.dart';
import '../../../domain/entities/expense_history_filter.dart';
import '../../widgets/category_visuals.dart';

/// Bottom sheet for applying expense filters.
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
  late final TextEditingController _minAmount;
  late final TextEditingController _maxAmount;
  late final TextEditingController _tagController;
  late List<String> _tags;
  late bool _receiptOnly;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.current.categoryId;
    _dateFrom = widget.current.dateFrom;
    _dateTo = widget.current.dateTo;
    _minAmount = TextEditingController(
      text: widget.current.minAmount?.toStringAsFixed(0),
    );
    _maxAmount = TextEditingController(
      text: widget.current.maxAmount?.toStringAsFixed(0),
    );
    _tagController = TextEditingController();
    _tags = List.of(widget.current.tags);
    _receiptOnly = widget.current.receiptOnly;
  }

  @override
  void dispose() {
    _minAmount.dispose();
    _maxAmount.dispose();
    _tagController.dispose();
    super.dispose();
  }

  bool get _hasAnyFilter =>
      _categoryId != null ||
      _dateFrom != null ||
      _dateTo != null ||
      _minAmount.text.isNotEmpty ||
      _maxAmount.text.isNotEmpty ||
      _tags.isNotEmpty ||
      _receiptOnly;

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_dateFrom ?? now) : (_dateTo ?? now),
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: isFrom ? 'From date' : 'To date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
        if (_dateTo != null && _dateTo!.isBefore(picked)) _dateTo = picked;
      } else {
        _dateTo = picked;
        if (_dateFrom != null && _dateFrom!.isAfter(picked)) _dateFrom = picked;
      }
    });
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isEmpty) return;
    setState(() {
      if (!_tags.contains(tag)) _tags.add(tag);
      _tagController.clear();
    });
  }

  void _reset() {
    setState(() {
      _categoryId = null;
      _dateFrom = null;
      _dateTo = null;
      _minAmount.clear();
      _maxAmount.clear();
      _tags = [];
      _receiptOnly = false;
    });
  }

  void _apply() {
    final min = double.tryParse(_minAmount.text);
    final max = double.tryParse(_maxAmount.text);
    final filter = ExpenseHistoryFilter(
      categoryId: _categoryId,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      minAmount: min,
      maxAmount: (min != null && max != null && max < min) ? min : max,
      tags: _tags,
      receiptOnly: _receiptOnly,
    );
    Navigator.pop(context, filter);
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy');
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSheetHeader(
            title: 'Filters',
            trailing: TextButton(
              onPressed: _hasAnyFilter ? _reset : null,
              child: const Text('Reset'),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel('Category'),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _categoryId == null,
                        onSelected: (_) => setState(() => _categoryId = null),
                      ),
                      for (final category in widget.categories)
                        ChoiceChip(
                          key: Key('filter_category_${category.id}'),
                          avatar: Icon(
                            CategoryVisuals.iconFor(category.icon),
                            size: AppSizes.iconSm,
                          ),
                          label: Text(category.name),
                          selected: _categoryId == category.id,
                          onSelected: (_) =>
                              setState(() => _categoryId = category.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  _SectionLabel('Date range'),
                  Row(
                    children: [
                      Expanded(
                        child: _DateButton(
                          label: _dateFrom == null
                              ? 'From'
                              : dateFmt.format(_dateFrom!),
                          isSet: _dateFrom != null,
                          onTap: () => _pickDate(isFrom: true),
                          onClear: _dateFrom == null
                              ? null
                              : () => setState(() => _dateFrom = null),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _DateButton(
                          label: _dateTo == null
                              ? 'To'
                              : dateFmt.format(_dateTo!),
                          isSet: _dateTo != null,
                          onTap: () => _pickDate(isFrom: false),
                          onClear: _dateTo == null
                              ? null
                              : () => setState(() => _dateTo = null),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  _SectionLabel('Amount range'),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minAmount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Min'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextField(
                          controller: _maxAmount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ],
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(labelText: 'Max'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  _SectionLabel('Tags'),
                  TextField(
                    controller: _tagController,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: 'Add a tag, e.g. lunch',
                      isDense: true,
                      suffixIcon: IconButton(
                        key: const Key('filterAddTag'),
                        tooltip: 'Add tag',
                        icon: const Icon(Icons.add_rounded),
                        onPressed: _addTag,
                      ),
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                  if (_tags.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final tag in _tags)
                          InputChip(
                            label: Text('#$tag'),
                            onDeleted: () => setState(() => _tags.remove(tag)),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),

                  SwitchListTile(
                    key: const Key('filterReceiptOnly'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Only expenses with a receipt'),
                    value: _receiptOnly,
                    onChanged: (value) => setState(() => _receiptOnly = value),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: FilledButton(
                    key: const Key('applyFilters'),
                    onPressed: _apply,
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final bool isSet;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateButton({
    required this.label,
    required this.isSet,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(
        isSet ? Icons.event_rounded : Icons.calendar_today_outlined,
        size: AppSizes.iconSm + 2,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          if (onClear != null) ...[
            const SizedBox(width: AppSpacing.xs),
            InkWell(
              onTap: onClear,
              borderRadius: AppSpacing.borderRadiusFull,
              child: const Padding(
                padding: EdgeInsets.all(AppSpacing.xxs),
                child: Icon(Icons.close_rounded, size: AppSizes.iconSm),
              ),
            ),
          ],
        ],
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
  return AppBottomSheet.show<ExpenseHistoryFilter>(
    context: context,
    builder: (context) =>
        FilterBottomSheet(current: current, categories: categories),
  );
}
