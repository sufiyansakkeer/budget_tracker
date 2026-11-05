import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/currency/currency_provider.dart';
import '../../../../core/currency/money_math.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/app_notice.dart';
import '../../../../core/widgets/app_page_body.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/dates/date_range_format.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/focus_after_transition.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../bills/domain/entities/bill_entity.dart';
import '../../../bills/domain/entities/bill_failure.dart';
import '../../../bills/domain/usecases/get_bills_usecase.dart';
import '../../../expenses/domain/entities/expense_failure.dart';
import '../../../expenses/domain/usecases/get_expenses_usecase.dart';
import '../../../expenses/presentation/widgets/form_field_error.dart';
import '../../../settings/domain/entities/currency_entity.dart';
import '../../domain/usecases/manage_budget_usecase.dart';
import '../widgets/budget_visuals.dart';
import '../../../../core/events/refresh_bus.dart';
import '../../../../core/widgets/app_animated_size.dart';
import '../../../../core/widgets/app_disclosure.dart';
import '../../../../core/widgets/app_form_action_bar.dart';
import '../../../../core/currency/money_input.dart';
import '../../../../core/currency/money_input_formatter.dart';
import '../../../../core/feedback/app_haptics.dart';
import '../../../../core/dates/calendar_dates.dart';
import '../start_next_period.dart';

/// Create or edit a budget.
///
/// Order of fields follows what the user needs to decide: name → amount and
/// currency → period → optional money set aside, which shapes Today's Safe
/// Spending → "More options" (icon, colour, notes), folded on a new budget.
/// The save action is pinned to the bottom, above the keyboard. Leaving
/// with unsaved input asks first.
///
/// A new budget becomes the active one when it runs today, or when the
/// active budget doesn't; otherwise the confirmation offers "Make active".
///
/// "Set aside (optional)" holds the budget's kept-aside amount and savings
/// goal. Each is 0 to the budget amount; together they may reach it (a
/// warning, not an error, since nothing is then free to spend). An empty
/// field means "not set".
class BudgetFormScreen extends StatefulWidget {
  /// When [budgetId] is provided, this screen edits that budget; otherwise it
  /// creates a new one.
  final String? budgetId;

  /// Creates the period after this budget's ("Start next period"): its
  /// amount, currency, set-asides and look, with the next dates.
  final String? nextAfterId;

  const BudgetFormScreen({super.key, this.budgetId, this.nextAfterId});

  /// "Today", for which budget a new one makes active; replaced in tests.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

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
  final _reserveController = TextEditingController();
  final _savingsController = TextEditingController();

  BudgetEntity? _budget;
  late DateTime _startDate;
  late DateTime _endDate;
  String _currency = 'INR';
  String? _color;
  String? _icon;
  bool _saving = false;
  bool _loading = false;
  bool _notFound = false;

  /// The budget couldn't be read (as opposed to no longer existing).
  bool _loadFailed = false;
  String? _dateError;
  String? _saveError;

  /// Unpaid bills linked to the budget being edited, for the currency
  /// warning.
  List<BillEntity> _linkedBills = const [];

  /// How many expenses the budget being edited holds, whatever their date;
  /// null until read, or when it cannot be read. Expenses carry no currency
  /// of their own, so a currency change relabels every one of them.
  int? _expenseCount;

  /// The dates of those expenses, to tell how many new dates leave out;
  /// null until read.
  List<DateTime>? _expenseDates;

  /// Whether the budget being edited is the active one (Home's budget).
  bool _isActiveBudget = false;

  /// How many purchases on Pay later tabs the budget being edited holds;
  /// null until read, or when it cannot be read (saving still checks).
  int? _tabPurchaseCount;

  final FocusNode _nameFocus = FocusNode();

  /// The form as opened (or as loaded), to tell whether leaving loses
  /// anything; null while a budget is still loading.
  String? _baseline;
  bool _lastDirty = false;
  bool _justSaved = false;

  bool get _isEditing => _budget != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = _startDate.addDays(30);
    _currency = getIt<CurrencyProvider>().currencyCode;
    for (final controller in [
      _nameController,
      _amountController,
      _notesController,
      _reserveController,
      _savingsController,
    ]) {
      controller.addListener(_onTextChanged);
    }
    if (widget.budgetId != null) {
      _loadBudget();
    } else if (widget.nextAfterId != null) {
      _prefillNextPeriod(widget.nextAfterId!);
    } else {
      _baseline = _signature();
      // Keyboard after the page has settled, not during the transition.
      requestFocusAfterTransition(context, _nameFocus);
    }
  }

  void _onTextChanged() {
    final dirty = _isDirty;
    if (dirty != _lastDirty && mounted) setState(() => _lastDirty = dirty);
  }

  String _signature() => [
    _nameController.text.trim(),
    _amountController.text.trim(),
    _currency,
    _startDate.toIso8601String(),
    _endDate.toIso8601String(),
    _color,
    _icon,
    _notesController.text.trim(),
    _reserveController.text.trim(),
    _savingsController.text.trim(),
  ].join('|');

  /// Whether leaving now would lose something the person entered.
  bool get _isDirty {
    if (_justSaved) return false;
    final baseline = _baseline;
    return baseline != null && _signature() != baseline;
  }

  Future<void> _requestClose() async {
    if (!_isDirty) return context.pop();
    FocusManager.instance.primaryFocus?.unfocus();
    final discard = await ConfirmationDialog.show(
      context: context,
      title: _isEditing ? 'Discard changes?' : 'Discard this budget?',
      message: _isEditing
          ? "Your changes haven't been saved."
          : "What you entered hasn't been saved.",
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      icon: Icons.edit_off_outlined,
      isDestructive: true,
    );
    if (discard && mounted) context.pop();
  }

  /// The form's fields from [budget].
  void _fill(BudgetEntity budget) {
    _nameController.text = budget.name;
    _amountController.text = _formatAmount(budget.monthlyAmount);
    _notesController.text = budget.notes ?? '';
    _reserveController.text = budget.reservedAmount == null
        ? ''
        : _formatAmount(budget.reservedAmount!);
    _savingsController.text = budget.savingsTarget == null
        ? ''
        : _formatAmount(budget.savingsTarget!);
    _startDate = budget.startDate;
    _endDate = budget.endDate;
    _currency = budget.currency;
    _color = budget.color;
    _icon = budget.icon;
  }

  /// Best effort: when the budget can't be read, the form starts blank.
  Future<void> _prefillNextPeriod(String sourceId) async {
    setState(() => _loading = true);
    try {
      final source = await _manageBudget.getById(sourceId);
      if (!mounted) return;
      if (source != null) {
        final next = StartNextPeriod.datesAfter(source);
        _fill(source);
        _startDate = next.start;
        _endDate = next.end;
      }
    } catch (e) {
      debugPrint('[error] Loading budget $sourceId for its next period: $e');
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _baseline = _signature();
    });
  }

  Future<void> _loadBudget() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
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
        _fill(budget);
        _budget = budget;
        _loading = false;
        _baseline = _signature();
      });
      _loadLinkedBills(budget.id);
      _loadExpenseCount(budget.id);
      _loadTabPurchaseCount(budget.id);
      _loadIsActive(budget.id);
    } catch (e) {
      debugPrint('[error] Loading budget ${widget.budgetId}: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  /// Best effort: without bills the currency warning is simply not shown.
  Future<void> _loadLinkedBills(String budgetId) async {
    try {
      final result = await getIt<GetBillsUseCase>()();
      if (!mounted) return;
      if (result case BillSuccess(:final data)) {
        setState(() {
          _linkedBills = data
              .where((b) => b.budgetId == budgetId && !b.isPaid)
              .toList();
        });
      }
    } catch (e) {
      debugPrint('[error] Loading bills linked to a budget: $e');
    }
  }

  /// Best effort: without a count the currency warning still shows, worded
  /// without a number.
  Future<void> _loadExpenseCount(String budgetId) async {
    try {
      if (!getIt.isRegistered<GetExpensesUseCase>()) return;
      final result = await getIt<GetExpensesUseCase>()(budgetId: budgetId);
      if (!mounted) return;
      if (result case ExpenseSuccess(:final data)) {
        setState(() {
          _expenseCount = data.length;
          _expenseDates = [for (final e in data) e.date];
        });
      }
    } catch (e) {
      // Unknown count: the warning is worded without one.
      debugPrint('[error] Counting a budget\'s expenses: $e');
    }
  }

  /// Best effort: unknown, the "won't run today" warning is not shown.
  Future<void> _loadIsActive(String budgetId) async {
    try {
      final activeId = await _manageBudget.activeBudgetId();
      if (!mounted) return;
      setState(() => _isActiveBudget = activeId == budgetId);
    } catch (e) {
      debugPrint('[error] Reading the active budget: $e');
    }
  }

  /// Best effort: without a count the reason shows when saving is refused.
  Future<void> _loadTabPurchaseCount(String budgetId) async {
    try {
      final count = await _manageBudget.tabPurchasesIn(budgetId);
      if (!mounted) return;
      setState(() => _tabPurchaseCount = count);
    } catch (e) {
      debugPrint('[error] Counting a budget\'s Pay later purchases: $e');
    }
  }

  /// Why the new currency can't be saved: the budget holds purchases on
  /// Pay later tabs in its current currency. Null when it can.
  String? get _tabCurrencyBlock {
    final budget = _budget;
    final count = _tabPurchaseCount ?? 0;
    if (budget == null || _currency == budget.currency || count <= 0) {
      return null;
    }
    return BudgetCurrencyLockedException(
      tabPurchases: count,
      currency: budget.currency,
    ).message;
  }

  /// Whether the edit changes the currency of a budget that may hold
  /// expenses (none known to be absent).
  bool get _relabelsExpenses {
    final budget = _budget;
    if (budget == null || _currency == budget.currency) return false;
    return (_expenseCount ?? 1) > 0;
  }

  /// "Your 12 expenses keep their amounts and will be shown in OMR". The
  /// same numbers in another currency: nothing is converted.
  String get _relabelSentence {
    final count = _expenseCount;
    final what = count == null
        ? 'The expenses in this budget'
        : count == 1
        ? 'The 1 expense in this budget'
        : 'The $count expenses in this budget';
    return '$what keep their amounts and will be counted in $_currency. '
        'Nothing is converted.';
  }

  /// Asked before saving a currency change that relabels expenses. Never
  /// silent: the user confirms that, say, ₹500 will read as 500 in the new
  /// currency, or keeps the old one.
  Future<bool> _confirmCurrencyChange() async {
    if (!_relabelsExpenses) return true;
    final from = _budget!.currency;
    final example = CurrencyFormatter.format(500, code: from);
    final after = CurrencyFormatter.format(500, code: _currency);
    return ConfirmationDialog.show(
      context: context,
      title: 'Change currency to $_currency?',
      message:
          '$_relabelSentence An expense of $example will read $after. To '
          'keep these amounts in $from, start a new budget in $_currency '
          'instead.',
      confirmLabel: 'Change currency',
      cancelLabel: 'Keep $from',
      icon: Icons.currency_exchange_rounded,
    );
  }

  /// Parsed set-aside field: null when empty (not set).
  static double? _parseOptional(String text) =>
      text.trim().isEmpty ? null : double.tryParse(text.trim());

  String? _validateSetAside(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final amount = double.tryParse(text);
    if (amount == null) return 'Enter a valid number.';
    return ManageBudgetUseCase.validateSetAside(
          amount,
          double.tryParse(_amountController.text) ?? 0,
        ) ??
        MoneyInput.decimalsError(text, _currency);
  }

  /// How many of the budget's expenses the edited dates leave out: they stay
  /// in the budget but stop counting toward Spent, Remaining and Today's
  /// Safe Spending. Null when none (or not known).
  String? get _excludedWarning {
    final dates = _expenseDates;
    if (!_isEditing || dates == null) return null;
    final start = _startDate.dateOnly;
    final end = _endDate.dateOnly;
    final count = dates.where((d) {
      final day = d.dateOnly;
      return day.isBefore(start) || day.isAfter(end);
    }).length;
    if (count == 0) return null;
    return count == 1
        ? '1 expense falls outside these dates'
        : '$count expenses fall outside these dates';
  }

  /// Whether the edit stops the active budget running today.
  bool get _stopsRunningToday {
    final budget = _budget;
    if (budget == null || budget.isArchived || !_isActiveBudget) return false;
    final today = BudgetFormScreen.clock();
    final edited = budget.copyWith(startDate: _startDate, endDate: _endDate);
    return budget.isActiveOn(today) && !edited.isActiveOn(today);
  }

  /// Inline warning when the kept-aside amount and savings goal together
  /// take the whole budget. Not a blocker.
  String? get _setAsideWarning {
    final budgetAmount = double.tryParse(_amountController.text) ?? 0;
    if (budgetAmount <= 0) return null;
    final reserve = _parseOptional(_reserveController.text) ?? 0;
    final savings = _parseOptional(_savingsController.text) ?? 0;
    // Each field reports its own range error.
    if (ManageBudgetUseCase.validateSetAside(reserve, budgetAmount) != null ||
        ManageBudgetUseCase.validateSetAside(savings, budgetAmount) != null) {
      return null;
    }
    if (!ManageBudgetUseCase.setAsideTakesAll(
      budgetAmount: budgetAmount,
      reserve: reserve,
      savings: savings,
      currency: _currency,
    )) {
      return null;
    }
    final sum = MoneyMath.forCurrency(
      _currency,
    ).toAmount(MoneyMath.forCurrency(_currency).sumUnits([reserve, savings]));
    final total = CurrencyFormatter.format(sum, code: _currency);
    final of = CurrencyFormatter.format(budgetAmount, code: _currency);
    return 'Together these set aside $total of $of, so nothing will be free '
        'to spend.';
  }

  /// Warning when the currency changes while bills in the old currency are
  /// linked: they are left out until updated.
  String? get _currencyWarning {
    final budget = _budget;
    if (budget == null || _currency == budget.currency) return null;
    final affected = _linkedBills.where((b) => b.currency != _currency);
    if (affected.isEmpty) return null;
    final count = affected.length;
    final codes = affected.map((b) => b.currency).toSet().join(' and ');
    return '$count linked ${count == 1 ? 'bill is' : 'bills are'} in $codes '
        "and won't be counted until you update ${count == 1 ? 'it' : 'them'}.";
  }

  /// Every saved decimal, so an OMR amount keeps its fils when edited.
  String _formatAmount(double amount) => MoneyInput.forInput(amount);

  @override
  void dispose() {
    _nameFocus.dispose();
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _reserveController.dispose();
    _savingsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _startDate : _endDate;
    // A period ends at least a day after it starts (saving refuses less).
    // An older budget that ends on its start day keeps that date in range.
    final earliestEnd = _startDate.addDays(1);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: isStart
          ? DateTime(2000)
          : (current.isBefore(earliestEnd) ? current : earliestEnd),
      lastDate: DateTime(2100),
      helpText: isStart ? 'Budget start date' : 'Budget end date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateError = null;
      if (isStart) {
        final length = calendarDaysBetween(_startDate, _endDate);
        _startDate = picked;
        // Keep the same number of days when the start moves.
        _endDate = picked.addDays(length);
      } else {
        _endDate = picked;
      }
    });
  }

  int get _dayCount => calendarDaysBetween(_startDate, _endDate) + 1;

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
      reservedAmount: _parseOptional(_reserveController.text),
      savingsTarget: _parseOptional(_savingsController.text),
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
          duration: AppMotion.respectReducedMotion(ctx, AppMotion.medium),
          curve: AppMotion.standardCurve,
        );
      }
      return;
    }

    if (_tabCurrencyBlock != null) {
      setState(
        () => _saveError = 'Keep this budget in ${_budget!.currency} to save.',
      );
      return;
    }
    if (_isEditing && !await _confirmCurrencyChange()) return;
    if (!mounted) return;

    setState(() => _saving = true);
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();
    final reserve = _parseOptional(_reserveController.text);
    final savings = _parseOptional(_savingsController.text);

    try {
      Object result = true;
      var activated = false;
      if (_isEditing) {
        // Built in full rather than with copyWith, whose nulls mean
        // "unchanged": a cleared colour, icon or note must save as cleared.
        final stored = _budget!;
        final updated = BudgetEntity(
          id: stored.id,
          name: _nameController.text.trim(),
          monthlyAmount: amount,
          remainingAmount: stored.remainingAmount,
          currency: _currency,
          startDate: _startDate,
          endDate: _endDate,
          isArchived: stored.isArchived,
          color: _color,
          icon: _icon,
          notes: notes,
          createdAt: stored.createdAt,
          updatedAt: DateTime.now(),
          reservedAmount: reserve,
          savingsTarget: savings,
        );
        await _manageBudget.update(updated);
      } else {
        // Read before creating, so the new budget can't stand in for a
        // missing active one.
        final today = BudgetFormScreen.clock();
        final activeId = await _manageBudget.activeBudgetId();
        final active = activeId == null
            ? null
            : await _manageBudget.getById(activeId);
        final activeRunning =
            active != null && !active.isArchived && active.isActiveOn(today);
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
            reservedAmount: reserve,
            savingsTarget: savings,
            createdAt: now,
            updatedAt: now,
          ),
        );
        // Planning ahead or backfilling keeps today's budget on Home.
        activated = created.isActiveOn(today) || !activeRunning;
        if (activated) await _manageBudget.setActive(created.id);
        result = created.id;
      }
      RefreshBuses.budgets.notifyChanged();
      if (!mounted) return;
      AppHaptics.confirm();
      setState(() => _justSaved = true);
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          _isEditing
              ? const SnackBar(content: Text('Budget updated'))
              : activated
              ? const SnackBar(content: Text('Budget created and set active'))
              : _makeActiveSnackBar(
                  messenger,
                  id: result as String,
                  name: _nameController.text.trim(),
                ),
        );
      context.pop(result);
    } on BudgetCurrencyLockedException catch (e) {
      // The count wasn't known on screen; the use case refused.
      debugPrint('[error] Saving budget: $e');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _tabPurchaseCount = e.tabPurchases;
        _saveError = 'Keep this budget in ${e.currency} to save.';
      });
    } catch (e) {
      debugPrint('[error] Saving budget: $e');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = _isEditing
            ? "Couldn't save your changes. Please try again."
            : "Couldn't create the budget. Please try again.";
      });
    }
  }

  /// "Budget created", with "Make active" for a budget that didn't become
  /// the active one. Outlives the form, so it holds what it needs.
  SnackBar _makeActiveSnackBar(
    ScaffoldMessengerState messenger, {
    required String id,
    required String name,
  }) {
    final manageBudget = _manageBudget;
    return SnackBar(
      content: const Text('Budget created'),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'Make active',
        onPressed: () async {
          String message;
          try {
            await manageBudget.setActive(id);
            RefreshBuses.budgets.notifyChanged();
            message = '$name is now your active budget';
          } catch (e) {
            debugPrint('[error] Making a new budget active: $e');
            message = "Couldn't make $name active. Try again from its details.";
          }
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final theme = Theme.of(context);
    final title = _isEditing
        ? 'Edit budget'
        : widget.nextAfterId != null
        ? 'Next period'
        : 'New budget';

    if (_loadFailed) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ErrorState(
          title: "Couldn't open this budget",
          message: "It's still on this device. Try again in a moment.",
          onRetry: _loadBudget,
        ),
      );
    }

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
                child: AppPageBody(
                  builder: (context, padding) => ListView(
                    padding: padding,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      // Name
                      TextFormField(
                        controller: _nameController,
                        focusNode: _nameFocus,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.done,
                              inputFormatters: [
                                MoneyInputFormatter(
                                  MoneyInput.maxDecimals(_currency),
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
                                prefixStyle: theme.textTheme.titleLarge
                                    ?.copyWith(
                                      color: theme.colorScheme.primary,
                                    ),
                                helperText:
                                    'The total for the whole budget period',
                              ),
                              // The set-aside checks depend on the amount.
                              onChanged: (_) => setState(() {}),
                              validator: (value) {
                                final amount = double.tryParse(value ?? '');
                                if (amount == null || amount <= 0) {
                                  return 'Enter an amount greater than zero.';
                                }
                                if (!MoneyMath.isWithinLimit(amount)) {
                                  return 'Enter an amount less than '
                                      '${MoneyMath.maxAmountLabel}.';
                                }
                                // E.g. after switching from OMR to INR.
                                return MoneyInput.decimalsError(
                                  value ?? '',
                                  _currency,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _CurrencyDropdown(
                            value: _selectedCurrencyCode,
                            currencies: _currencies,
                            onChanged: (code) =>
                                setState(() => _currency = code),
                          ),
                        ],
                      ),
                      if (_tabCurrencyBlock != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AppNotice(
                          key: const ValueKey('budgetCurrencyTabsBlock'),
                          tone: AppTone.critical,
                          icon: Icons.credit_card_outlined,
                          title: 'Currency can\'t change',
                          message: _tabCurrencyBlock!,
                        ),
                      ],
                      if (_relabelsExpenses && _tabCurrencyBlock == null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AppNotice(
                          key: const ValueKey('budgetCurrencyExpensesWarning'),
                          tone: AppTone.caution,
                          icon: Icons.currency_exchange_rounded,
                          title: 'Expenses keep their amounts',
                          message: _relabelSentence,
                        ),
                      ],
                      if (_currencyWarning != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AppNotice(
                          key: const ValueKey('budgetCurrencyBillsWarning'),
                          tone: AppTone.caution,
                          icon: Icons.receipt_long_rounded,
                          title: 'Some bills left out',
                          message: _currencyWarning!,
                        ),
                      ],
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
                      if (_excludedWarning != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AppNotice(
                          key: const ValueKey('budgetDatesExcludeWarning'),
                          tone: AppTone.caution,
                          icon: Icons.event_busy_rounded,
                          title: _excludedWarning!,
                          message:
                              "They stay in this budget but won't count toward "
                              "Spent, Remaining or Today's Safe Spending.",
                        ),
                      ],
                      if (_stopsRunningToday) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AppNotice(
                          key: const ValueKey('budgetDatesNotToday'),
                          tone: AppTone.caution,
                          icon: Icons.today_rounded,
                          title: "This budget won't run today",
                          message:
                              "It's your active budget, so Home will have no "
                              "Today's Safe Spending until a budget runs today.",
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),

                      // Set aside
                      _SetAsideSection(
                        currency: _currency,
                        reserveController: _reserveController,
                        savingsController: _savingsController,
                        validator: _validateSetAside,
                        warning: _setAsideWarning,
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Look and notes: optional, folded away on a new
                      // budget and open when editing one.
                      AppDisclosure(
                        key: const ValueKey('budgetMoreOptions'),
                        title: 'More options',
                        summary: 'Icon, colour and notes',
                        initiallyExpanded: _isEditing,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                              onIconSelected: (icon) => setState(
                                () => _icon = _icon == icon ? null : icon,
                              ),
                              onColorSelected: (color) => setState(
                                () => _color = _color == color ? null : color,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            TextFormField(
                              controller: _notesController,
                              maxLines: 3,
                              minLines: 1,
                              keyboardType: TextInputType.multiline,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Notes',
                                hintText:
                                    'Anything to remember about this budget',
                                alignLabelWithHint: true,
                                prefixIcon: Icon(Icons.notes_rounded),
                              ),
                            ),
                          ],
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
            ),
      bottomNavigationBar: _loading
          ? null
          : AppFormActionBar(
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

/// The currency beside the amount: symbol and code in the menu, the code
/// alone once chosen.
class _CurrencyDropdown extends StatelessWidget {
  final String? value;
  final List<CurrencyEntity> currencies;
  final ValueChanged<String> onChanged;

  const _CurrencyDropdown({
    required this.value,
    required this.currencies,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Currency',
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: AppSpacing.borderRadiusMd,
        ),
        child: DropdownButton<String>(
          value: value,
          hint: const Text('Currency'),
          underline: const SizedBox.shrink(),
          borderRadius: AppSpacing.borderRadiusMd,
          onChanged: (code) {
            if (code != null) onChanged(code);
          },
          items: [
            for (final currency in currencies)
              DropdownMenuItem<String>(
                value: currency.code,
                child: Text('${currency.symbol}  ${currency.code}'),
              ),
          ],
          selectedItemBuilder: (context) => [
            for (final currency in currencies)
              Center(
                child: Text(currency.code, style: theme.textTheme.labelLarge),
              ),
          ],
        ),
      ),
    );
  }
}

class _SetAsideSection extends StatelessWidget {
  final String currency;
  final TextEditingController reserveController;
  final TextEditingController savingsController;
  final FormFieldValidator<String> validator;
  final String? warning;
  final VoidCallback onChanged;

  const _SetAsideSection({
    required this.currency,
    required this.reserveController,
    required this.savingsController,
    required this.validator,
    required this.warning,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget field({
      required Key key,
      required TextEditingController controller,
      required String label,
      required String helper,
      required IconData icon,
    }) => TextFormField(
      key: key,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      inputFormatters: [MoneyInputFormatter(MoneyInput.maxDecimals(currency))],
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Not set',
        prefixIcon: Icon(icon),
        prefixText: '${CurrencyFormatter.symbolFor(currency)} ',
        helperText: helper,
        helperMaxLines: 2,
      ),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: validator,
      onChanged: (_) => onChanged(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Set aside (optional)', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        field(
          key: const ValueKey('budgetReserveField'),
          controller: reserveController,
          label: 'Keep aside',
          helper: "Money in this budget you don't want counted as spendable",
          icon: Icons.savings_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        field(
          key: const ValueKey('budgetSavingsField'),
          controller: savingsController,
          label: 'Savings goal',
          helper: 'Money you want left unspent at the end of the period',
          icon: Icons.flag_outlined,
        ),
        AppAnimatedSize(
          duration: AppMotion.respectReducedMotion(context, AppMotion.standard),
          curve: AppMotion.standardCurve,
          alignment: Alignment.topCenter,
          child: warning == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: StatusCard(
                    key: const ValueKey('budgetSetAsideWarning'),
                    color: context.appColors.warning,
                    icon: Icons.warning_amber_rounded,
                    message: warning!,
                  ),
                ),
        ),
      ],
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
    final valid = dayCount > 1;
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
      onTap: onTap,
      excludeSemantics: true,
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
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: AppSizes.touchTarget,
          height: AppSizes.touchTarget,
          child: Center(
            child: AnimatedContainer(
              duration: AppMotion.respectReducedMotion(context, AppMotion.fast),
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
    );
  }
}
