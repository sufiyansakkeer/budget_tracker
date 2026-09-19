import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/currency/currency_provider.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../expenses/presentation/widgets/form_field_error.dart';
import '../../../settings/domain/entities/currency_entity.dart';
import '../../domain/usecases/manage_budget_usecase.dart';
import '../bloc/budget_bloc.dart';
import '../widgets/budget_visuals.dart';

/// Create or edit a budget.
///
/// Order of fields follows what the user needs to decide: name → amount and
/// currency → period → optional look and notes. The save action is pinned to
/// the bottom so it is never hidden behind the keyboard.
class BudgetFormScreen extends StatefulWidget {
  /// When [budgetId] is provided, this screen edits that budget; otherwise it
  /// creates a new one.
  final String? budgetId;

  const BudgetFormScreen({super.key, this.budgetId});

  @override
  State<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends State<BudgetFormScreen> {
  late final ManageBudgetUseCase _manageBudget = getIt<ManageBudgetUseCase>();
  final _formKey = GlobalKey<FormState>();
  final _dateKey = GlobalKey();

  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  BudgetEntity? _budget;
  late DateTime _startDate;
  late DateTime _endDate;
  String _currency = 'INR';
  String? _color;
  String? _icon;
  bool _saving = false;
  bool _loading = false;
  bool _notFound = false;
  String? _dateError;
  String? _saveError;

  bool get _isEditing => _budget != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = _startDate.add(const Duration(days: 30));
    _currency = getIt<CurrencyProvider>().currencyCode;
    if (widget.budgetId != null) _loadBudget();
  }

  Future<void> _loadBudget() async {
    setState(() => _loading = true);
    try {
      final budget = await _manageBudget.getById(widget.budgetId!);
      if (!mounted) return;
      if (budget == null) {
        setState(() {
          _loading = false;
          _notFound = true;
        });
        return;
      }
      setState(() {
        _nameController.text = budget.name;
        _amountController.text = _formatAmount(budget.monthlyAmount);
        _notesController.text = budget.notes ?? '';
        _budget = budget;
        _startDate = budget.startDate;
        _endDate = budget.endDate;
        _currency = budget.currency;
        _color = budget.color;
        _icon = budget.icon;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _notFound = true;
      });
    }
  }

  String _formatAmount(double amount) => amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: isStart ? DateTime(2000) : _startDate,
      lastDate: DateTime(2100),
      helpText: isStart ? 'Budget start date' : 'Budget end date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateError = null;
      if (isStart) {
        final length = _endDate.difference(_startDate);
        _startDate = picked;
        // Keep the same duration when the start moves.
        _endDate = picked.add(length);
      } else {
        _endDate = picked;
      }
    });
  }

  int get _dayCount => _endDate.difference(_startDate).inDays + 1;

  List<CurrencyEntity> get _currencies {
    final byCode = <String, CurrencyEntity>{};
    for (final currency in availableCurrencies) {
      byCode.putIfAbsent(currency.code, () => currency);
    }
    return byCode.values.toList();
  }

  String? get _selectedCurrencyCode =>
      _currencies.where((c) => c.code == _currency).length == 1
      ? _currency
      : null;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saveError = null;
      _dateError = null;
    });
    final fieldsOk = _formKey.currentState!.validate();

    final amount = double.tryParse(_amountController.text) ?? 0;
    final error = _manageBudget.validate(
      _nameController.text,
      amount,
      _startDate,
      _endDate,
    );
    if (!fieldsOk) return;
    if (error != null) {
      // Name/amount are already handled by field validators, so a remaining
      // error concerns the dates.
      setState(() => _dateError = error);
      final ctx = _dateKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: AppMotion.medium,
          curve: AppMotion.standardCurve,
        );
      }
      return;
    }

    setState(() => _saving = true);
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    try {
      if (_isEditing) {
        final updated = _budget!.copyWith(
          name: _nameController.text.trim(),
          monthlyAmount: amount,
          currency: _currency,
          startDate: _startDate,
          endDate: _endDate,
          color: _color,
          icon: _icon,
          notes: notes,
          updatedAt: DateTime.now(),
        );
        await _manageBudget.update(updated);
      } else {
        final now = DateTime.now();
        final created = await _manageBudget.create(
          BudgetEntity(
            id: 'budget_${now.microsecondsSinceEpoch}',
            name: _nameController.text.trim(),
            monthlyAmount: amount,
            remainingAmount: amount,
            currency: _currency,
            startDate: _startDate,
            endDate: _endDate,
            color: _color,
            icon: _icon,
            notes: notes,
            createdAt: now,
            updatedAt: now,
          ),
        );
        // A newly created budget becomes the active one.
        await _manageBudget.setActive(created.id);
      }
      BudgetRefreshBus.instance.notifyChanged();
      if (!mounted) return;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Budget updated' : 'Budget created and set active',
            ),
          ),
        );
      context.pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = _isEditing
            ? "Couldn't save your changes. Please try again."
            : "Couldn't create the budget. Please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _isEditing ? 'Edit budget' : 'New budget';

    if (_notFound) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Budget not found',
          message: 'It may have been deleted.',
          actionLabel: 'Back to budgets',
          actionIcon: Icons.arrow_back_rounded,
          onAction: () =>
              context.canPop() ? context.pop() : context.go('/app/budgets'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const FormSkeleton(rows: 5)
          : AbsorbPointer(
              absorbing: _saving,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: AppSpacing.pagePadding,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    // Name
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      autofocus: !_isEditing,
                      decoration: const InputDecoration(
                        labelText: 'Budget name',
                        hintText: 'e.g. Personal, Vacation, Wedding',
                        prefixIcon: Icon(Icons.label_outline_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Give your budget a name.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Amount + currency
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}'),
                              ),
                            ],
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                            decoration: InputDecoration(
                              labelText: 'Budget amount',
                              prefixText:
                                  '${CurrencyFormatter.symbolFor(_currency)} ',
                              prefixStyle: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                              helperText:
                                  'The total for the whole budget period',
                            ),
                            validator: (value) {
                              final amount = double.tryParse(value ?? '');
                              if (amount == null || amount <= 0) {
                                return 'Enter an amount greater than zero.';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Semantics(
                          label: 'Currency',
                          child: Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.smd,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainer,
                              borderRadius: AppSpacing.borderRadiusMd,
                            ),
                            child: DropdownButton<String>(
                              value: _selectedCurrencyCode,
                              hint: const Text('Currency'),
                              underline: const SizedBox.shrink(),
                              borderRadius: AppSpacing.borderRadiusMd,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _currency = value);
                                }
                              },
                              items: [
                                for (final currency in _currencies)
                                  DropdownMenuItem<String>(
                                    value: currency.code,
                                    child: Text(
                                      '${currency.symbol}  ${currency.code}',
                                    ),
                                  ),
                              ],
                              selectedItemBuilder: (context) => [
                                for (final currency in _currencies)
                                  Center(
                                    child: Text(
                                      currency.code,
                                      style: theme.textTheme.labelLarge,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Period
                    KeyedSubtree(
                      key: _dateKey,
                      child: _PeriodSection(
                        startDate: _startDate,
                        endDate: _endDate,
                        dayCount: _dayCount,
                        errorText: _dateError,
                        onPickStart: () => _pickDate(isStart: true),
                        onPickEnd: () => _pickDate(isStart: false),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Look
                    Text('Look', style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Optional. Helps you tell budgets apart in lists.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _IconAndColorPicker(
                      selectedIcon: _icon,
                      selectedColor: _color,
                      onIconSelected: (icon) =>
                          setState(() => _icon = _icon == icon ? null : icon),
                      onColorSelected: (color) => setState(
                        () => _color = _color == color ? null : color,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      minLines: 1,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Anything to remember about this budget',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    if (_saveError != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      StatusCard(
                        color: theme.colorScheme.error,
                        icon: Icons.error_outline_rounded,
                        message: _saveError!,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: PrimaryButton(
                onPressed: _saving ? null : _save,
                isLoading: _saving,
                icon: _isEditing ? Icons.check_rounded : Icons.add_rounded,
                label: _isEditing ? 'Save changes' : 'Create budget',
              ),
            ),
    );
  }
}

class _PeriodSection extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final int dayCount;
  final String? errorText;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _PeriodSection({
    required this.startDate,
    required this.endDate,
    required this.dayCount,
    required this.errorText,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valid = dayCount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Period', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final start = _DateField(
              label: 'Starts',
              date: startDate,
              onTap: onPickStart,
              hasError: errorText != null,
            );
            final end = _DateField(
              label: 'Ends',
              date: endDate,
              onTap: onPickEnd,
              hasError: errorText != null,
            );
            if (constraints.maxWidth < 340) {
              return Column(
                children: [
                  start,
                  const SizedBox(height: AppSpacing.sm),
                  end,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: start),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: end),
              ],
            );
          },
        ),
        if (errorText != null)
          FormFieldError(message: errorText!)
        else ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                Icons.timelapse_rounded,
                size: AppSizes.iconSm,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  valid
                      ? '$dayCount ${dayCount == 1 ? 'day' : 'days'} · '
                            '${formatDateRange(startDate, endDate)}'
                      : 'The end date must be after the start date',
                  key: const Key('budgetDaysSummary'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  final bool hasError;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = DateFormat('d MMM yyyy').format(date);
    return Semantics(
      button: true,
      label: '$label $text',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: AppSpacing.borderRadiusMd,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: const Icon(Icons.event_rounded),
              enabledBorder: hasError
                  ? theme.inputDecorationTheme.errorBorder
                  : null,
            ),
            child: Text(
              text,
              style: theme.textTheme.bodyLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconAndColorPicker extends StatelessWidget {
  final String? selectedIcon;
  final String? selectedColor;
  final ValueChanged<String> onIconSelected;
  final ValueChanged<String> onColorSelected;

  const _IconAndColorPicker({
    required this.selectedIcon,
    required this.selectedColor,
    required this.onIconSelected,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final (id, label, icon) in BudgetVisuals.iconOptions)
              ChoiceChip(
                avatar: Icon(icon, size: AppSizes.iconSm + 2),
                label: Text(label),
                selected: selectedIcon == id,
                onSelected: (_) => onIconSelected(id),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.smd),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final (hex, name) in BudgetVisuals.colorOptions)
              _ColorSwatch(
                color: BudgetVisuals.rawColor(hex),
                name: name,
                selected: selectedColor == hex,
                onTap: () => onColorSelected(hex),
                surface: theme.colorScheme.surface,
              ),
          ],
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final String name;
  final bool selected;
  final VoidCallback onTap;
  final Color surface;

  const _ColorSwatch({
    required this.color,
    required this.name,
    required this.selected,
    required this.onTap,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Semantics(
      button: true,
      selected: selected,
      label: '$name colour',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: AppSizes.touchTarget,
            height: AppSizes.touchTarget,
            child: Center(
              child: AnimatedContainer(
                duration: AppMotion.respectReducedMotion(
                  context,
                  AppMotion.fast,
                ),
                width: selected ? 36 : 30,
                height: selected ? 36 : 30,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? theme.colorScheme.onSurface : surface,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check_rounded, color: onColor, size: 18)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
