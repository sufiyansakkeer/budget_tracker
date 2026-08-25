import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_provider.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../settings/domain/entities/currency_entity.dart';
import '../../domain/usecases/manage_budget_usecase.dart';

/// Create or edit a budget.
///
/// Fields are grouped into labelled sections for an easier, less dense layout,
/// and the date range shows a live duration summary.
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

  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  BudgetEntity? _budget;
  late DateTime _startDate;
  late DateTime _endDate;
  String _currency = 'INR';
  String? _color;
  String? _icon;
  bool _saving = false;
  bool _loading = false;
  String? _error;

  bool get _isEditing => _budget != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _amountController = TextEditingController();
    _notesController = TextEditingController();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = _startDate.add(const Duration(days: 30));
    _currency = getIt<CurrencyProvider>().currencyCode;
    if (widget.budgetId != null) {
      _loadBudget();
    }
  }

  Future<void> _loadBudget() async {
    setState(() => _loading = true);
    final budget = await _manageBudget.getById(widget.budgetId!);
    if (!mounted) return;
    if (budget == null) {
      setState(() {
        _loading = false;
        _error = 'Budget not found.';
      });
      return;
    }
    _nameController.text = budget.name;
    _amountController.text = budget.monthlyAmount.toString();
    _notesController.text = budget.notes ?? '';
    _budget = budget;
    _startDate = budget.startDate;
    _endDate = budget.endDate;
    _currency = budget.currency;
    _color = budget.color;
    _icon = budget.icon;
    setState(() => _loading = false);
  }

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
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: isStart ? 'Select start date' : 'Select end date',
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(picked)) {
          _endDate = picked.add(const Duration(days: 30));
        }
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0;
    final error = _manageBudget.validate(
      _nameController.text,
      amount,
      _startDate,
      _endDate,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

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
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
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
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            createdAt: now,
            updatedAt: now,
          ),
        );
        // Make the first/just-created budget active.
        await _manageBudget.setActive(created.id);
      }

      if (!mounted) return;
      context.pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _isEditing
            ? 'Could not update the budget.'
            : 'Could not create the budget.';
      });
    }
  }

  int get _dayCount => _endDate.difference(_startDate).inDays + 1;

  List<CurrencyEntity> get _currencies {
    final currenciesByCode = <String, CurrencyEntity>{};
    for (final currency in availableCurrencies) {
      currenciesByCode.putIfAbsent(currency.code, () => currency);
    }
    return currenciesByCode.values.toList();
  }

  String? get _selectedCurrencyCode {
    final matches = _currencies.where((currency) => currency.code == _currency);
    return matches.length == 1 ? _currency : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Budget' : 'New Budget')),
      body: SafeArea(
        child: _loading
            ? const _BudgetFormSkeleton()
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    AppHeader(
                      title: _isEditing ? 'Edit Budget' : 'New Budget',
                      subtitle: _isEditing
                          ? 'Update your budget details'
                          : 'Set up a new budget in a few steps',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _FormSection(
                      title: 'General',
                      children: [
                        TextFormField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Budget Name',
                            hintText: 'e.g. Personal, Vacation, Wedding',
                            prefixIcon: Icon(
                              Icons.account_balance_wallet_rounded,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Budget name cannot be empty.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _amountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Budget Amount',
                                  prefixIcon: Icon(
                                    Icons.currency_rupee_rounded,
                                  ),
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
                            DropdownButton<String>(
                              value: _selectedCurrencyCode,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _currency = value);
                                }
                              },
                              items: _currencies
                                  .map(
                                    (currency) => DropdownMenuItem<String>(
                                      value: currency.code,
                                      child: Text(currency.symbol),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _FormSection(
                      title: 'Date Range',
                      children: [
                        _DateRangePicker(
                          startDate: _startDate,
                          endDate: _endDate,
                          onPickStart: () => _pickDate(isStart: true),
                          onPickEnd: () => _pickDate(isStart: false),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          '$_dayCount days',
                          key: const Key('budgetDaysSummary'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _FormSection(
                      title: 'Style',
                      children: [
                        _IconAndColorPicker(
                          selectedIcon: _icon,
                          selectedColor: _color,
                          onIconSelected: (icon) =>
                              setState(() => _icon = icon),
                          onColorSelected: (color) =>
                              setState(() => _color = color),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _FormSection(
                      title: 'Notes',
                      children: [
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Notes (optional)',
                            prefixIcon: Icon(Icons.notes_rounded),
                          ),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      onPressed: _saving ? null : _save,
                      isLoading: _saving,
                      label: _isEditing ? 'Save Changes' : 'Create Budget',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _FormSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(child: Column(children: children)),
      ],
    );
  }
}

class _BudgetFormSkeleton extends StatelessWidget {
  const _BudgetFormSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: const [
        SkeletonBox(width: 180, height: 24),
        SizedBox(height: AppSpacing.lg),
        SkeletonBox(width: double.infinity, height: 72),
        SizedBox(height: AppSpacing.lg),
        SkeletonBox(width: double.infinity, height: 120),
        SizedBox(height: AppSpacing.lg),
        SkeletonBox(width: double.infinity, height: 140),
        SizedBox(height: AppSpacing.lg),
        SkeletonBox(width: double.infinity, height: 96),
      ],
    );
  }
}

class _DateRangePicker extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _DateRangePicker({
    required this.startDate,
    required this.endDate,
    required this.onPickStart,
    required this.onPickEnd,
  });

  String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final start = _DateField(
          label: 'Start',
          value: _fmt(startDate),
          onTap: onPickStart,
        );
        final end = _DateField(
          label: 'End',
          value: _fmt(endDate),
          onTap: onPickEnd,
        );

        if (constraints.maxWidth >= 420) {
          return Row(
            children: [
              Expanded(child: start),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Icon(Icons.arrow_forward_rounded),
              ),
              Expanded(child: end),
            ],
          );
        }
        return Column(
          children: [
            start,
            const SizedBox(height: AppSpacing.sm),
            end,
          ],
        );
      },
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event_rounded),
        ),
        child: Text(value),
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

  static const _icons = [
    'personal',
    'family',
    'vacation',
    'wedding',
    'business',
    'travel',
    'home',
  ];

  static const _colors = [
    '0xFF2196F3',
    '0xFF4CAF50',
    '0xFFFF9800',
    '0xFFF44336',
    '0xFF9C27B0',
    '0xFF009688',
  ];

  IconData _iconFor(String name) {
    switch (name) {
      case 'personal':
        return Icons.person_rounded;
      case 'family':
        return Icons.family_restroom_rounded;
      case 'vacation':
        return Icons.beach_access_rounded;
      case 'wedding':
        return Icons.favorite_rounded;
      case 'business':
        return Icons.business_center_rounded;
      case 'travel':
        return Icons.flight_takeoff_rounded;
      case 'home':
        return Icons.home_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }

  Color _colorFor(String hex) {
    final value = int.tryParse(hex.replaceFirst('0x', ''), radix: 16) ?? 0;
    return Color(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Icon'),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: 8,
          children: _icons
              .map(
                (icon) => ChoiceChip(
                  avatar: Icon(_iconFor(icon), size: 18),
                  label: const SizedBox.shrink(),
                  selected: selectedIcon == icon,
                  onSelected: (_) => onIconSelected(icon),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text('Color'),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: 8,
          children: _colors
              .map(
                (color) => InkWell(
                  onTap: () => onColorSelected(color),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _colorFor(color),
                      shape: BoxShape.circle,
                      border: selectedColor == color
                          ? Border.all(width: 3, color: Colors.black54)
                          : null,
                    ),
                    child: selectedColor == color
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
