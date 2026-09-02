import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/di/injection.dart';
import '../../../budget/domain/usecases/manage_budget_usecase.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/validators/expense_validator.dart';
import '../bloc/expense_bloc.dart';
import '../bloc/expense_event.dart';
import '../bloc/expense_state.dart';
import '../widgets/category_picker.dart';
import '../widgets/expense_amount_field.dart';
import '../widgets/expense_date_picker.dart';
import '../widgets/expense_form_actions.dart';
import '../widgets/expense_note_field.dart';
import '../widgets/expense_time_picker.dart';
import '../widgets/receipt_picker.dart';
import '../widgets/tag_input_field.dart';
import '../../../../core/theme/app_colors_extension.dart';

/// Add/Edit expense form. Pass [expenseId] to edit an existing expense.
///
/// The form is budget-aware: it shows a budget picker (defaulting to the
/// active budget), uses the selected budget's currency, and validates that the
/// expense date falls within the selected budget's period.
class ExpenseFormScreen extends StatefulWidget {
  final String? expenseId;

  const ExpenseFormScreen({super.key, this.expenseId});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  late final ManageBudgetUseCase _manageBudget = getIt<ManageBudgetUseCase>();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  List<String> _tags = [];
  String? _selectedCategoryId;
  String? _amountError;
  String? _categoryError;
  String? _dateError;
  DateTime? _date;
  TimeOfDay? _time;
  String? _receiptPath;

  List<BudgetEntity> _budgets = [];
  String? _selectedBudgetId;
  String? _budgetCurrencyCode = 'INR';
  String? _budgetError;
  bool _loadingBudgets = true;

  bool get _isEditing => widget.expenseId != null;

  @override
  void initState() {
    super.initState();
    context.read<ExpenseBloc>().add(const ExpenseLoadCategories());
    // Initialize the default date/time defaults only for new expenses. The
    // values are captured once by the BLoC and kept in state.
    if (!_isEditing) {
      context.read<ExpenseBloc>().add(const ExpenseInitialize());
    }
    _loadBudgets();
    if (_isEditing) {
      context.read<ExpenseBloc>().add(ExpenseLoadById(widget.expenseId!));
    }
  }

  Future<void> _loadBudgets() async {
    final budgets = await _manageBudget.getAll();
    final activeId = await _manageBudget.activeBudgetId();
    if (!mounted) return;
    setState(() {
      _budgets = budgets.where((b) => !b.isArchived).toList();
      _selectedBudgetId ??= activeId;
      _loadingBudgets = false;
    });
    _applyBudgetCurrency();
  }

  void _applyBudgetCurrency() {
    final budget = _selectedBudget();
    if (budget != null) {
      setState(() => _budgetCurrencyCode = budget.currency);
    }
  }

  BudgetEntity? _selectedBudget() {
    if (_selectedBudgetId == null) return null;
    for (final b in _budgets) {
      if (b.id == _selectedBudgetId) return b;
    }
    return null;
  }

  String _currencySymbol() {
    switch (_budgetCurrencyCode) {
      case 'INR':
        return '₹';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'AED':
        return 'د.إ';
      case 'SAR':
        return 'ر.س';
      default:
        return '₹';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _populateFromExpense(ExpenseEntity expense) {
    _amountController.text = expense.amount.toString();
    _noteController.text = expense.note ?? '';
    _selectedCategoryId = expense.categoryId;
    _date = expense.date;
    _time = TimeOfDay(hour: expense.time.hour, minute: expense.time.minute);
    _receiptPath = expense.receiptImagePath;
    _tags = List.of(expense.tags);
    _selectedBudgetId = expense.budgetId;
  }

  void _onAmountChanged(String value) {
    setState(() {
      _amountError = ExpenseValidator.validateAmount(value);
    });
  }

  void _onCategoryChanged(String categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _categoryError = null;
    });
  }

  void _onBudgetChanged(String? budgetId) {
    setState(() {
      _selectedBudgetId = budgetId;
      _budgetError = null;
      _dateError = null;
    });
    _applyBudgetCurrency();
  }

  void _onDateChanged(DateTime? date) {
    setState(() {
      _date = date;
      _dateError = null;
    });
  }

  String? _validateDateInBudget(DateTime? date) {
    if (date == null) return null;
    final budget = _selectedBudget();
    if (budget == null) return null;

    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(
      budget.startDate.year,
      budget.startDate.month,
      budget.startDate.day,
    );
    final end = DateTime(
      budget.endDate.year,
      budget.endDate.month,
      budget.endDate.day,
    );
    if (day.isBefore(start) || day.isAfter(end)) {
      return 'This expense date is outside the selected budget period.';
    }
    return null;
  }

  void _save() {
    FocusManager.instance.primaryFocus?.unfocus();

    final amountError = ExpenseValidator.validateAmount(_amountController.text);
    final categoryError = _selectedCategoryId == null
        ? 'Please select a category'
        : null;
    final futureDateError = ExpenseValidator.validateDate(_date);
    final inBudgetError = _validateDateInBudget(_date);
    final budgetError = _selectedBudgetId == null
        ? 'Please select a budget'
        : null;

    setState(() {
      _amountError = amountError;
      _categoryError = categoryError;
      _dateError = futureDateError ?? inBudgetError;
      _budgetError = budgetError;
    });

    if (!_formKey.currentState!.validate()) return;
    if (_amountError != null ||
        _categoryError != null ||
        _dateError != null ||
        _budgetError != null) {
      return;
    }

    final amount = double.parse(_amountController.text.trim());
    final now = DateTime.now();
    final time = _time ?? TimeOfDay.now();
    final expenseDate = _date ?? now;
    final expenseTime = DateTime(
      expenseDate.year,
      expenseDate.month,
      expenseDate.day,
      time.hour,
      time.minute,
    );

    final expense = ExpenseEntity(
      id: _isEditing ? widget.expenseId! : const Uuid().v4(),
      budgetId: _selectedBudgetId!,
      amount: amount,
      categoryId: _selectedCategoryId!,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      date: expenseDate,
      time: expenseTime,
      receiptImagePath: _receiptPath,
      tags: _tags,
      createdAt: now,
      updatedAt: now,
    );

    if (_isEditing) {
      context.read<ExpenseBloc>().add(ExpenseUpdate(expense));
    } else {
      context.read<ExpenseBloc>().add(ExpenseCreate(expense));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Expense' : 'Add Expense')),
      body: BlocConsumer<ExpenseBloc, ExpenseState>(
        listener: (context, state) {
          if (state.isBusy) return;

          if (state.status == ExpenseBlocStatus.success) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.message ?? 'Saved')));
            context.read<ExpenseBloc>().add(const ExpenseClearMessage());
            // When the Add Expense screen was opened from the home-screen
            // widget deep-link it is the initial route — there is nothing to
            // pop back to.  Detect this and navigate to the Dashboard instead.
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              context.pop();
            } else {
              context.go('/app/home');
            }
          } else if (state.status == ExpenseBlocStatus.error) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.message ?? 'Something went wrong'),
                  backgroundColor: context.appColors.error,
                ),
              );
            context.read<ExpenseBloc>().add(const ExpenseClearMessage());
          }

          // Populate fields once the expense loads for editing.
          if (state.expense != null &&
              _isEditing &&
              _amountController.text.isEmpty) {
            _populateFromExpense(state.expense!);
          }

          // Apply the BLoC-provided default date/time for new expenses.
          if (!_isEditing && _date == null) {
            if (state.initialDate != null) {
              _date = state.initialDate;
            }
            if (state.initialTime != null && _time == null) {
              _time = TimeOfDay(
                hour: state.initialTime!.hour,
                minute: state.initialTime!.minute,
              );
            }
          }
        },
        builder: (context, state) {
          final isSaving = state.isBusy;

          // If editing and still loading without data yet.
          if (_isEditing && state.status == ExpenseBlocStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ExpenseAmountField(
                    controller: _amountController,
                    currencySymbol: _currencySymbol(),
                    errorText: _amountError,
                    onChanged: _onAmountChanged,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildBudgetPicker(),
                  if (_budgetError != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _budgetError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  CategoryPicker(
                    categories: state.categories,
                    selectedCategoryId: _selectedCategoryId,
                    onSelected: _onCategoryChanged,
                  ),
                  if (_categoryError != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _categoryError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _buildDateTimeRow(),
                  if (_dateError != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _dateError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  ExpenseNoteField(controller: _noteController),
                  const SizedBox(height: AppSpacing.md),
                  TagInputField(
                    initialTags: _tags,
                    onTagsChanged: (tags) => setState(() => _tags = tags),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ReceiptPicker(
                    receiptPath: _receiptPath,
                    onChanged: (path) => setState(() => _receiptPath = path),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ExpenseFormActions(
                    isSaving: isSaving,
                    isEditing: _isEditing,
                    onSave: _save,
                    onCancel: () {
                      final navigator = Navigator.of(context);
                      if (navigator.canPop()) {
                        context.pop();
                      } else {
                        context.go('/app/home');
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBudgetPicker() {
    if (_loadingBudgets) {
      return const LinearProgressIndicator();
    }
    if (_budgets.isEmpty) {
      return Text(
        'No budgets available. Create a budget first.',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    return DropdownButtonFormField<String>(
      value: _selectedBudgetId,
      decoration: const InputDecoration(
        labelText: 'Budget',
        prefixIcon: Icon(Icons.account_balance_wallet_rounded),
      ),
      items: _budgets
          .map(
            (b) => DropdownMenuItem(
              value: b.id,
              child: Text(
                '${b.name} (${_fmtRange(b.startDate, b.endDate)})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: _onBudgetChanged,
    );
  }

  String _fmtRange(DateTime start, DateTime end) {
    String two(int n) => n.toString().padLeft(2, '0');
    String d(DateTime x) => '${two(x.day)}/${two(x.month)}';
    return '${d(start)} → ${d(end)}';
  }

  Widget _buildDateTimeRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        final datePicker = ExpenseDatePicker(
          date: _date,
          onChanged: _onDateChanged,
        );
        final timePicker = ExpenseTimePicker(
          time: _time,
          onChanged: (t) => setState(() => _time = t),
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: datePicker),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: timePicker),
            ],
          );
        }
        return Column(
          children: [
            datePicker,
            const SizedBox(height: AppSpacing.md),
            timePicker,
          ],
        );
      },
    );
  }
}
