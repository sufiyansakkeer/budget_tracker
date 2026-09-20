import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/loading_skeleton.dart';
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

/// Add/Edit expense form. Pass [expenseId] to edit an existing expense, or
/// [copyFromId] to start a new expense pre-filled from another one (its
/// amount, category, note, tags and budget; the date is today and no receipt
/// is copied).
///
/// Priority order on screen: amount → category → date & time → optional
/// details (budget, note, tags, receipt). Date and time are pre-filled by the
/// BLoC for new expenses and stay editable. The budget picker defaults to the
/// active budget, drives the currency symbol, and the expense date must fall
/// inside the selected budget's period.
class ExpenseFormScreen extends StatefulWidget {
  final String? expenseId;
  final String? copyFromId;

  const ExpenseFormScreen({super.key, this.expenseId, this.copyFromId})
    : assert(
        expenseId == null || copyFromId == null,
        'Edit or duplicate, not both',
      );

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  late final ManageBudgetUseCase _manageBudget = getIt<ManageBudgetUseCase>();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  // Anchors for scroll-to-first-error.
  final _amountKey = GlobalKey();
  final _categoryKey = GlobalKey();
  final _dateKey = GlobalKey();
  final _budgetKey = GlobalKey();

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
  String? _budgetError;
  bool _loadingBudgets = true;
  bool _budgetsFailed = false;
  bool _populated = false;
  bool _justSaved = false;

  bool get _isEditing => widget.expenseId != null;
  bool get _isDuplicating => widget.copyFromId != null;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<ExpenseBloc>();
    bloc.add(const ExpenseLoadCategories());
    // Default date/time are captured once by the BLoC and kept in state.
    if (!_isEditing) bloc.add(const ExpenseInitialize());
    _loadBudgets();
    if (_isEditing) bloc.add(ExpenseLoadById(widget.expenseId!));
    if (_isDuplicating) bloc.add(ExpenseLoadById(widget.copyFromId!));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadBudgets() async {
    setState(() {
      _loadingBudgets = true;
      _budgetsFailed = false;
    });
    try {
      final budgets = await _manageBudget.getAll();
      final activeId = await _manageBudget.activeBudgetId();
      if (!mounted) return;
      setState(() {
        _budgets = budgets.where((b) => !b.isArchived).toList();
        _selectedBudgetId ??= activeId;
        _loadingBudgets = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingBudgets = false;
        _budgetsFailed = true;
      });
    }
  }

  BudgetEntity? get _selectedBudget {
    for (final b in _budgets) {
      if (b.id == _selectedBudgetId) return b;
    }
    return null;
  }

  String get _currencySymbol =>
      CurrencyFormatter.symbolFor(_selectedBudget?.currency);

  /// Pre-fills a *new* expense from [source]: what was bought and for which
  /// budget, but dated now and without the receipt file.
  void _populateAsCopy(ExpenseEntity source) {
    setState(() {
      _amountController.text = _formatAmountForInput(source.amount);
      _noteController.text = source.note ?? '';
      _selectedCategoryId = source.categoryId;
      _tags = List.of(source.tags);
      _selectedBudgetId = source.budgetId;
      _populated = true;
    });
  }

  void _populateFromExpense(ExpenseEntity expense) {
    setState(() {
      _amountController.text = _formatAmountForInput(expense.amount);
      _noteController.text = expense.note ?? '';
      _selectedCategoryId = expense.categoryId;
      _date = expense.date;
      _time = TimeOfDay(hour: expense.time.hour, minute: expense.time.minute);
      _receiptPath = expense.receiptImagePath;
      _tags = List.of(expense.tags);
      _selectedBudgetId = expense.budgetId;
      _populated = true;
    });
  }

  String _formatAmountForInput(double amount) {
    if (amount == amount.roundToDouble()) return amount.toStringAsFixed(0);
    return amount.toStringAsFixed(2);
  }

  String? _validateDateInBudget(DateTime? date) {
    if (date == null) return null;
    final budget = _selectedBudget;
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
      return 'Outside the ${budget.name} budget period '
          '(${formatShortDateRange(budget.startDate, budget.endDate)}).';
    }
    return null;
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: AppMotion.respectReducedMotion(ctx, AppMotion.medium),
      curve: AppMotion.standardCurve,
      alignment: 0.1,
    );
  }

  void _save() {
    FocusManager.instance.primaryFocus?.unfocus();

    final amountError = ExpenseValidator.validateAmount(_amountController.text);
    final categoryError = _selectedCategoryId == null
        ? 'Choose a category for this expense.'
        : null;
    final dateError =
        ExpenseValidator.validateDate(_date) ?? _validateDateInBudget(_date);
    final budgetError = _selectedBudgetId == null
        ? 'Choose the budget this expense belongs to.'
        : null;

    setState(() {
      _amountError = amountError;
      _categoryError = categoryError;
      _dateError = dateError;
      _budgetError = budgetError;
    });
    _formKey.currentState?.validate();

    if (amountError != null) return _scrollTo(_amountKey);
    if (categoryError != null) return _scrollTo(_categoryKey);
    if (dateError != null) return _scrollTo(_dateKey);
    if (budgetError != null) return _scrollTo(_budgetKey);

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

    final bloc = context.read<ExpenseBloc>();
    bloc.add(_isEditing ? ExpenseUpdate(expense) : ExpenseCreate(expense));
  }

  void _close() {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      // Opened from the home-screen widget deep link: nothing to pop.
      context.go('/app/home');
    }
  }

  Future<void> _onSaved(String? message) async {
    HapticFeedback.lightImpact();
    setState(() => _justSaved = true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message ?? 'Saved')));
    // Let the check mark land before leaving the screen.
    await Future<void>.delayed(
      AppMotion.respectReducedMotion(context, AppMotion.emphasized),
    );
    if (!mounted) return;
    _close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'Edit expense'
              : _isDuplicating
              ? 'Duplicate expense'
              : 'Add expense',
        ),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: _close,
        ),
      ),
      body: BlocConsumer<ExpenseBloc, ExpenseState>(
        listener: (context, state) {
          if (state.status == ExpenseBlocStatus.success && !_justSaved) {
            context.read<ExpenseBloc>().add(const ExpenseClearMessage());
            _onSaved(state.message);
          } else if (state.status == ExpenseBlocStatus.error) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.message ?? "Couldn't save the expense"),
                  action: SnackBarAction(label: 'Retry', onPressed: _save),
                ),
              );
            context.read<ExpenseBloc>().add(const ExpenseClearMessage());
          }

          // Populate once the expense loads for editing / duplicating.
          if (_isEditing && !_populated && state.expense != null) {
            _populateFromExpense(state.expense!);
          } else if (_isDuplicating &&
              !_populated &&
              state.expense?.id == widget.copyFromId) {
            _populateAsCopy(state.expense!);
          }

          // Apply the BLoC-provided default date/time for new expenses.
          if (!_isEditing && (_date == null || _time == null)) {
            setState(() {
              _date ??= state.initialDate;
              if (_time == null && state.initialTime != null) {
                _time = TimeOfDay(
                  hour: state.initialTime!.hour,
                  minute: state.initialTime!.minute,
                );
              }
            });
          }
        },
        builder: (context, state) {
          final isSaving = state.isBusy;

          if ((_isEditing || _isDuplicating) &&
              !_populated &&
              state.status == ExpenseBlocStatus.loading) {
            return const FormSkeleton(rows: 5);
          }

          return AbsorbPointer(
            absorbing: isSaving || _justSaved,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: AppSpacing.pagePadding,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  // 1. Amount
                  KeyedSubtree(
                    key: _amountKey,
                    child: ExpenseAmountField(
                      controller: _amountController,
                      currencySymbol: _currencySymbol,
                      errorText: _amountError,
                      autofocus: !_isEditing,
                      onChanged: (value) => setState(() {
                        _amountError = value.isEmpty
                            ? null
                            : ExpenseValidator.validateAmount(value);
                      }),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 2. Category
                  KeyedSubtree(
                    key: _categoryKey,
                    child: CategoryPicker(
                      categories: state.categories,
                      selectedCategoryId: _selectedCategoryId,
                      errorText: _categoryError,
                      onSelected: (id) => setState(() {
                        _selectedCategoryId = id;
                        _categoryError = null;
                      }),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 3. Date & time
                  KeyedSubtree(key: _dateKey, child: _buildDateTimeRow()),
                  const SizedBox(height: AppSpacing.lg),

                  // 4. Details
                  Text(
                    'Details',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  KeyedSubtree(key: _budgetKey, child: _buildBudgetPicker()),
                  const SizedBox(height: AppSpacing.md),
                  ExpenseNoteField(controller: _noteController),
                  const SizedBox(height: AppSpacing.md),
                  TagInputField(
                    key: ValueKey('tags_$_populated'),
                    initialTags: _tags,
                    onTagsChanged: (tags) => setState(() => _tags = tags),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ReceiptPicker(
                    receiptPath: _receiptPath,
                    onChanged: (path) => setState(() => _receiptPath = path),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          );
        },
      ),
      // Sticky action bar: always visible, sits above the keyboard.
      bottomNavigationBar: BlocBuilder<ExpenseBloc, ExpenseState>(
        buildWhen: (a, b) => a.isBusy != b.isBusy,
        builder: (context, state) => SafeArea(
          minimum: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: ExpenseFormActions(
            isSaving: state.isBusy,
            isSaved: _justSaved,
            isEditing: _isEditing,
            onSave: _save,
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetPicker() {
    final theme = Theme.of(context);
    if (_loadingBudgets) {
      return const Shimmer(
        child: SkeletonBox(height: 56, radius: AppSpacing.radiusMd),
      );
    }
    if (_budgetsFailed) {
      return StatusCard(
        color: theme.colorScheme.error,
        icon: Icons.error_outline_rounded,
        message: "Couldn't load your budgets.",
        trailing: TextButton(
          onPressed: _loadBudgets,
          child: const Text('Retry'),
        ),
      );
    }
    if (_budgets.isEmpty) {
      return StatusCard(
        color: theme.colorScheme.error,
        icon: Icons.account_balance_wallet_outlined,
        title: 'No budget yet',
        message: 'Create a budget before adding expenses.',
        trailing: TextButton(
          onPressed: () async {
            await context.push('/app/budgets/create');
            if (mounted) _loadBudgets();
          },
          child: const Text('Create'),
        ),
      );
    }
    return DropdownButtonFormField<String>(
      value: _budgets.any((b) => b.id == _selectedBudgetId)
          ? _selectedBudgetId
          : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Budget',
        prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
        errorText: _budgetError,
      ),
      items: [
        for (final b in _budgets)
          DropdownMenuItem(
            value: b.id,
            child: Text(
              '${b.name} · ${formatShortDateRange(b.startDate, b.endDate)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (id) => setState(() {
        _selectedBudgetId = id;
        _budgetError = null;
        _dateError = null;
      }),
    );
  }

  Widget _buildDateTimeRow() {
    final datePicker = ExpenseDatePicker(
      date: _date,
      errorText: _dateError,
      onChanged: (date) => setState(() {
        _date = date;
        _dateError = null;
      }),
    );
    final timePicker = ExpenseTimePicker(
      time: _time,
      onChanged: (t) => setState(() => _time = t),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 340) {
          return Column(
            children: [
              datePicker,
              const SizedBox(height: AppSpacing.md),
              timePicker,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: datePicker),
            const SizedBox(width: AppSpacing.smd),
            Expanded(flex: 2, child: timePicker),
          ],
        );
      },
    );
  }
}
