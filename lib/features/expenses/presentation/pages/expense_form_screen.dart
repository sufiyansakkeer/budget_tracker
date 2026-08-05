import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
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

/// Add/Edit expense form. Pass [expenseId] to edit an existing expense.
class ExpenseFormScreen extends StatefulWidget {
  final String? expenseId;

  const ExpenseFormScreen({super.key, this.expenseId});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  List<String> _tags = [];
  String? _selectedCategoryId;
  String? _amountError;
  String? _categoryError;
  DateTime? _date;
  TimeOfDay? _time;
  String? _receiptPath;

  bool get _isEditing => widget.expenseId != null;

  @override
  void initState() {
    super.initState();
    context.read<ExpenseBloc>().add(const ExpenseLoadCategories());
    if (_isEditing) {
      context.read<ExpenseBloc>().add(ExpenseLoadById(widget.expenseId!));
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

  void _save() {
    FocusManager.instance.primaryFocus?.unfocus();

    final amountError = ExpenseValidator.validateAmount(_amountController.text);
    final categoryError = _selectedCategoryId == null
        ? 'Please select a category'
        : null;
    final dateError = ExpenseValidator.validateDate(_date);

    setState(() {
      _amountError = amountError;
      _categoryError = categoryError;
    });

    if (!_formKey.currentState!.validate()) return;
    if (_amountError != null || _categoryError != null || dateError != null) {
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
            context.pop();
          } else if (state.status == ExpenseBlocStatus.error) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.message ?? 'Something went wrong'),
                  backgroundColor: AppColors.dangerRed,
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
                    onCancel: () => context.pop(),
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

  Widget _buildDateTimeRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        final datePicker = ExpenseDatePicker(
          date: _date,
          onChanged: (d) => setState(() => _date = d),
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

  String _currencySymbol() {
    // A default symbol is used; the real symbol comes from the budget.
    // In the future this could be read from the budget entity.
    return '₹';
  }
}
