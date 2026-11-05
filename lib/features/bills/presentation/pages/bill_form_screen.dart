import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/currency/money_math.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_form_action_bar.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/app_notice.dart';
import '../../../../core/dates/date_range_format.dart';
import '../../../../core/widgets/app_page_body.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/widgets/focus_after_transition.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../budget/domain/usecases/manage_budget_usecase.dart';
import '../../../settings/domain/entities/currency_entity.dart';
import '../../../settings/domain/entities/settings_failure.dart';
import '../../../settings/domain/usecases/load_settings_usecase.dart';
import '../../domain/entities/bill_entity.dart';
import '../../domain/entities/bill_enums.dart';
import '../../../expenses/presentation/widgets/form_field_error.dart';
import '../../domain/validators/bill_validator.dart';
import '../bloc/bill_bloc.dart';
import '../bloc/bill_event.dart';
import '../bloc/bill_state.dart';
import 'bill_budget_link.dart';
import 'bill_widgets.dart';
import '../../../../core/widgets/app_animated_size.dart';
import '../../../../core/widgets/app_disclosure.dart';
import '../../../../core/currency/money_input.dart';
import '../../../../core/currency/money_input_formatter.dart';
import '../../../../core/feedback/app_haptics.dart';
import '../../../../core/dates/calendar_dates.dart';
import '../../../../core/notifications/notification_permission_notice.dart';

/// Add/Edit bill form screen.
///
/// Order: what and how much → which budget pays it → when it is due, then
/// "More options" (category, repeat, reminder, note), folded on a new bill.
///
/// The budget picker is optional and starts at "Not linked". A bill is only
/// set aside from a budget in its own currency, so picking a budget in
/// another currency switches the bill to it: silently on create (with a
/// helper saying so), after a confirmation on edit, where the amount was
/// entered in the old currency.
/// The save button is pinned to the bottom, above the keyboard. Closing
/// with unsaved input asks first.
class BillFormScreen extends StatefulWidget {
  final String? billId;

  const BillFormScreen({super.key, this.billId});

  @override
  State<BillFormScreen> createState() => _BillFormScreenState();
}

class _BillFormScreenState extends State<BillFormScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _intervalController = TextEditingController(text: '1');
  final _dueDateKey = GlobalKey();

  String? _titleError;
  String? _amountError;
  String? _dueDateError;
  String? _intervalError;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  BillCategory _selectedCategory = BillCategory.other;
  bool _isRecurring = false;
  RecurrenceType _recurrenceType = RecurrenceType.monthly;
  int _recurrenceInterval = 1;
  bool _reminderEnabled = true;
  int _reminderOffsetDays = 1;
  String _currency = 'INR';
  BillEntity? _original;
  bool _populated = false;

  /// [_signature] when the form was filled in, to tell an edit apart.
  String? _baseline;
  bool _lastDirty = false;
  bool _justSaved = false;

  List<BudgetEntity> _budgets = const [];
  bool _loadingBudgets = true;
  bool _budgetsFailed = false;
  String? _budgetId;

  /// Set when picking a budget switched the bill's currency.
  String? _currencyNote;

  /// The currency was chosen by hand (a bill not linked to a budget), so the
  /// settings currency no longer replaces it.
  bool _currencyChosen = false;

  /// Bumped to rebuild the picker when a currency change is cancelled, so
  /// it shows the budget that is still selected.
  int _pickerResets = 0;

  final FocusNode _titleFocus = FocusNode();

  bool get _isEditing => widget.billId != null;

  @override
  void initState() {
    super.initState();
    _loadCurrency();
    _loadBudgets();
    if (_isEditing) {
      context.read<BillBloc>().add(BillLoadById(widget.billId!));
    } else {
      // New bills default to being due today so the form saves in one tap.
      final now = DateTime.now();
      _dueDate = DateTime(now.year, now.month, now.day);
      _baseline = _signature();
      // Keyboard after the page has settled, not during the transition.
      requestFocusAfterTransition(context, _titleFocus);
    }
    for (final c in [
      _titleController,
      _amountController,
      _noteController,
      _intervalController,
    ]) {
      c.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() {
    final dirty = _isDirty;
    if (dirty != _lastDirty && mounted) setState(() => _lastDirty = dirty);
  }

  // The currency counts only when chosen by hand: otherwise it follows the
  // settings or the budget picked.
  String _signature() => [
    if (_currencyChosen) _currency,
    _titleController.text.trim(),
    _amountController.text.trim(),
    _noteController.text.trim(),
    _intervalController.text.trim(),
    _dueDate?.toIso8601String(),
    _dueTime == null ? null : '${_dueTime!.hour}:${_dueTime!.minute}',
    _selectedCategory.name,
    _isRecurring,
    _recurrenceType.name,
    _reminderEnabled,
    _reminderOffsetDays,
    _budgetId,
  ].join('|');

  /// Whether leaving now would lose something the person entered. An edit
  /// still loading has nothing to lose.
  bool get _isDirty {
    if (_justSaved) return false;
    final baseline = _baseline;
    return baseline != null && _signature() != baseline;
  }

  Future<void> _requestClose() async {
    if (!_isDirty) return _close();
    FocusManager.instance.primaryFocus?.unfocus();
    final discard = await ConfirmationDialog.show(
      context: context,
      title: _isEditing ? 'Discard changes?' : 'Discard this bill?',
      message: _isEditing
          ? "Your changes haven't been saved."
          : "What you entered hasn't been saved.",
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      icon: Icons.edit_off_outlined,
      isDestructive: true,
    );
    if (discard && mounted) _close();
  }

  Future<void> _loadCurrency() async {
    try {
      final result = await getIt<LoadSettingsUseCase>()();
      if (result case SettingsSuccess(:final data)) {
        // A budget picked meanwhile already set the currency.
        if (mounted && !_populated && _budgetId == null && !_currencyChosen) {
          setState(() => _currency = data.currencyCode);
        }
      }
    } catch (e) {
      // Keep the default currency.
      debugPrint('[error] Loading the currency setting: $e');
    }
  }

  Future<void> _loadBudgets() async {
    setState(() {
      _loadingBudgets = true;
      _budgetsFailed = false;
    });
    try {
      final budgets = await getIt<ManageBudgetUseCase>().getAll();
      if (!mounted) return;
      setState(() {
        _budgets = budgets;
        _loadingBudgets = false;
      });
    } catch (e) {
      debugPrint('[error] Loading budgets for the bill form: $e');
      if (!mounted) return;
      setState(() {
        _loadingBudgets = false;
        _budgetsFailed = true;
      });
    }
  }

  /// The budget id to save. While budgets are unknown (loading or failed)
  /// the bill keeps its link; once loaded, a link to a budget that no longer
  /// exists is dropped rather than written back.
  String? get _budgetIdToSave {
    if (_budgetId == null || _loadingBudgets || _budgetsFailed) {
      return _budgetId;
    }
    return _budgets.any((b) => b.id == _budgetId) ? _budgetId : null;
  }

  Future<void> _onBudgetPicked(String? id) async {
    if (id == null) {
      setState(() {
        _budgetId = null;
        _currencyNote = null;
      });
      return;
    }
    final budget = _budgets.firstWhere((b) => b.id == id);
    final note =
        'Amount is in ${budget.currency}, the currency of ${budget.name}';
    if (budget.currency == _currency) {
      setState(() {
        _budgetId = id;
        _currencyNote = null;
      });
      return;
    }
    if (!_isEditing) {
      setState(() {
        _budgetId = id;
        _currency = budget.currency;
        _currencyNote = note;
      });
      return;
    }

    final amount = _amountController.text.trim();
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Change this bill to ${budget.currency}?',
      message: amount.isEmpty
          ? 'A bill is set aside only from a budget in its own currency. '
                'Enter the amount in ${budget.currency}.'
          : 'The amount $amount will mean ${budget.currency} $amount. '
                "Edit the amount if that's wrong.",
      confirmLabel: 'Change to ${budget.currency}',
      icon: Icons.currency_exchange_rounded,
    );
    if (!mounted) return;
    setState(() {
      if (confirmed) {
        _budgetId = id;
        _currency = budget.currency;
        _currencyNote = note;
      } else {
        _pickerResets++;
      }
    });
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  void _populateFromBill(BillEntity bill) {
    setState(() {
      _original = bill;
      _populated = true;
      _titleController.text = bill.title;
      // Every saved decimal, so OMR 12.125 is not edited back as 12.13.
      _amountController.text = MoneyInput.forInput(bill.amount);
      _noteController.text = bill.note ?? '';
      _dueDate = bill.dueDate;
      if (bill.dueTime != null) {
        _dueTime = TimeOfDay(
          hour: bill.dueTime!.hour,
          minute: bill.dueTime!.minute,
        );
      }
      _selectedCategory = bill.category;
      _isRecurring = bill.isRecurring;
      _recurrenceType = bill.recurrenceType == RecurrenceType.none
          ? RecurrenceType.monthly
          : bill.recurrenceType;
      _recurrenceInterval = bill.recurrenceInterval;
      _intervalController.text = '${bill.recurrenceInterval}';
      _reminderEnabled = bill.reminderEnabled;
      _reminderOffsetDays = bill.reminderOffsetDays;
      _currency = bill.currency;
      _budgetId = bill.budgetId;
      _baseline = _signature();
    });
  }

  String? _validateTitle() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return 'Give the bill a name.';
    if (title.length > BillValidator.maxTitleLength) {
      return 'Keep the name under ${BillValidator.maxTitleLength} characters.';
    }
    return null;
  }

  String? _validateAmount() {
    final text = _amountController.text.trim();
    if (text.isEmpty) return 'Enter the amount due.';
    final value = double.tryParse(text);
    if (value == null) return 'Enter a valid number.';
    if (value <= 0) return 'The amount must be greater than zero.';
    if (!MoneyMath.isWithinLimit(value)) {
      return 'The amount must be less than ${MoneyMath.maxAmountLabel}.';
    }
    // The currency's minor units, never fewer than two (OMR three).
    return MoneyInput.decimalsError(text, _currency);
  }

  /// The repeat interval as typed. An empty or zero field used to be ignored,
  /// saving the previous interval while the field showed something else.
  String? _validateInterval() {
    if (!_isRecurring) return null;
    final n = int.tryParse(_intervalController.text.trim());
    if (n == null || n < 1) return 'Enter how often it repeats, 1 or more.';
    _recurrenceInterval = n;
    return null;
  }

  void _save() {
    FocusManager.instance.primaryFocus?.unfocus();

    final titleError = _validateTitle();
    final amountError = _validateAmount();
    final dueDateError = _dueDate == null ? 'Choose a due date.' : null;
    final intervalError = _validateInterval();
    setState(() {
      _titleError = titleError;
      _amountError = amountError;
      _dueDateError = dueDateError;
      _intervalError = intervalError;
    });
    if (titleError != null || amountError != null || intervalError != null) {
      return;
    }
    if (dueDateError != null) {
      final ctx = _dueDateKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: AppMotion.respectReducedMotion(ctx, AppMotion.medium),
          curve: AppMotion.standardCurve,
        );
      }
      return;
    }

    final now = DateTime.now();
    final bill = BillEntity(
      id: _isEditing ? widget.billId! : const Uuid().v4(),
      title: _titleController.text.trim(),
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      amount: double.parse(_amountController.text.trim()),
      currency: _currency,
      category: _selectedCategory,
      budgetId: _budgetIdToSave,
      dueDate: _dueDate!,
      dueTime: _dueTime != null
          ? DateTime(
              _dueDate!.year,
              _dueDate!.month,
              _dueDate!.day,
              _dueTime!.hour,
              _dueTime!.minute,
            )
          : null,
      isRecurring: _isRecurring,
      recurrenceType: _isRecurring ? _recurrenceType : RecurrenceType.none,
      recurrenceInterval: _isRecurring ? _recurrenceInterval : 1,
      reminderEnabled: _reminderEnabled,
      reminderOffsetDays: _reminderOffsetDays,
      // Editing keeps the bill's payment state and creation time.
      isPaid: _original?.isPaid ?? false,
      paidDate: _original?.paidDate,
      createdAt: _original?.createdAt ?? now,
      updatedAt: now,
    );

    context.read<BillBloc>().add(
      _isEditing ? BillUpdate(bill) : BillCreate(bill),
    );
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final initial = _dueDate ?? now;
    final lastYear = DateTime(now.year - 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      // An unpaid bill can be due long ago; the picker needs it in range.
      firstDate: initial.isBefore(lastYear) ? initial : lastYear,
      lastDate: DateTime(now.year + 10, 12, 31),
      helpText: 'Due date',
    );
    if (picked != null && mounted) {
      setState(() {
        _dueDate = picked;
        _dueDateError = null;
      });
    }
  }

  Future<void> _pickDueTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Due time',
    );
    if (picked != null && mounted) setState(() => _dueTime = picked);
  }

  void _close() => context.canPop() ? context.pop() : context.go('/app/bills');

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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit bill' : 'Add bill'),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: _requestClose,
        ),
      ),
      body: BlocConsumer<BillBloc, BillState>(
        listener: (context, state) {
          if (state.isBusy) return;
          if (state.status == BillBlocStatus.success) {
            AppHaptics.confirm();
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.message ?? 'Saved')));
            context.read<BillBloc>().add(const BillClearMessage());
            _justSaved = true;
            _close();
          } else if (state.status == BillBlocStatus.error) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.message ?? "Couldn't save the bill"),
                  action: SnackBarAction(label: 'Retry', onPressed: _save),
                ),
              );
            context.read<BillBloc>().add(const BillClearMessage());
          }
          if (_isEditing && !_populated && state.selectedBill != null) {
            _populateFromBill(state.selectedBill!);
          }
        },
        builder: (context, state) {
          if (_isEditing &&
              !_populated &&
              state.status == BillBlocStatus.loading) {
            return const FormSkeleton(rows: 5);
          }
          if (_isEditing &&
              !_populated &&
              state.selectedBill == null &&
              state.status != BillBlocStatus.loading &&
              state.status != BillBlocStatus.initial) {
            return Center(
              child: Text(
                'Bill not found',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          return AbsorbPointer(
            absorbing: state.isBusy,
            child: AppPageBody(
              builder: (context, padding) => ListView(
                padding: padding,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  // What
                  TextFormField(
                    controller: _titleController,
                    focusNode: _titleFocus,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Bill name',
                      hintText: 'e.g. Rent, Electricity, Netflix',
                      prefixIcon: const Icon(Icons.receipt_long_outlined),
                      errorText: _titleError,
                    ),
                    onChanged: (_) {
                      if (_titleError != null) {
                        setState(() => _titleError = null);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // How much, and in which currency while not linked: a
                  // linked bill is in its budget's currency.
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
                            MoneyInputFormatter(
                              MoneyInput.maxDecimals(_currency),
                            ),
                          ],
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          decoration: InputDecoration(
                            labelText: 'Amount',
                            hintText: '0.00',
                            prefixText:
                                '${CurrencyFormatter.symbolFor(_currency)} ',
                            prefixStyle: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                            errorText: _amountError,
                          ),
                          onChanged: (_) {
                            if (_amountError != null) {
                              setState(() => _amountError = null);
                            }
                          },
                        ),
                      ),
                      if (_budgetId == null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        SizedBox(
                          width: 112,
                          child: _CurrencyPicker(
                            key: const Key('billCurrencyPicker'),
                            value: _currency,
                            onChanged: (code) => setState(() {
                              _currency = code;
                              _currencyChosen = true;
                              _amountError = null;
                            }),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Which budget pays it
                  _buildBudgetPicker(theme),
                  const SizedBox(height: AppSpacing.md),

                  // When
                  Text('Due', style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  KeyedSubtree(
                    key: _dueDateKey,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _PickerField(
                            label: 'Date',
                            icon: Icons.calendar_today_outlined,
                            value: _dueDate == null
                                ? 'Select date'
                                : _dueLabel(_dueDate!),
                            errorText: _dueDateError,
                            onTap: _pickDueDate,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.smd),
                        Expanded(
                          flex: 2,
                          child: _PickerField(
                            label: 'Time',
                            icon: Icons.access_time_rounded,
                            value: _dueTime == null
                                ? '9:00 AM'
                                : _dueTime!.format(context),
                            hint: _dueTime == null ? 'Default' : null,
                            onTap: _pickDueTime,
                            onClear: _dueTime == null
                                ? null
                                : () => setState(() => _dueTime = null),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Category, repeat, reminder and note: folded on a new
                  // bill, open when editing one.
                  AppDisclosure(
                    key: const ValueKey('billMoreOptions'),
                    title: 'More options',
                    summary: _moreOptionsSummary(),
                    initiallyExpanded: _isEditing,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Category
                        DropdownButtonFormField<BillCategory>(
                          value: _selectedCategory,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            prefixIcon: Icon(
                              BillVisuals.iconFor(_selectedCategory),
                            ),
                          ),
                          items: [
                            for (final cat in BillCategory.values)
                              DropdownMenuItem(
                                value: cat,
                                child: Row(
                                  children: [
                                    Icon(
                                      BillVisuals.iconFor(cat),
                                      size: AppSizes.iconMd,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: AppSpacing.smd),
                                    Text(cat.label),
                                  ],
                                ),
                              ),
                          ],
                          selectedItemBuilder: (context) => [
                            for (final cat in BillCategory.values)
                              Text(cat.label),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedCategory = value);
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        _ToggleSection(
                          icon: Icons.repeat_rounded,
                          title: 'Repeat this bill',
                          subtitle: _isRecurring
                              ? _recurrenceSummary()
                              : 'One-time bill',
                          value: _isRecurring,
                          onChanged: (value) =>
                              setState(() => _isRecurring = value),
                          child: _RepeatOptions(
                            type: _recurrenceType,
                            onTypeChanged: (type) =>
                                setState(() => _recurrenceType = type),
                            intervalController: _intervalController,
                            onIntervalChanged: (value) {
                              final n = int.tryParse(value);
                              setState(() {
                                if (n != null && n >= 1) {
                                  _recurrenceInterval = n;
                                }
                                // 0 is wrong as typed; empty waits for save.
                                _intervalError = n != null && n < 1
                                    ? 'Enter how often it repeats, 1 or more.'
                                    : null;
                              });
                            },
                            unitLabel: _unitLabel(),
                            intervalError: _intervalError,
                          ),
                        ),
                        _ToggleSection(
                          icon: Icons.notifications_outlined,
                          title: 'Remind me',
                          subtitle: _reminderEnabled
                              ? _reminderSummary()
                              : 'No reminder',
                          value: _reminderEnabled,
                          onChanged: (value) =>
                              setState(() => _reminderEnabled = value),
                          child: _ReminderOffsets(
                            selected: _reminderOffsetDays,
                            hasPassed: _reminderHasPassed,
                            onSelected: (days) =>
                                setState(() => _reminderOffsetDays = days),
                          ),
                        ),
                        NotificationPermissionNotice(
                          remindersOn: _reminderEnabled,
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Note
                        TextFormField(
                          controller: _noteController,
                          maxLines: 3,
                          minLines: 1,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Note',
                            hintText:
                                'Account number, provider, anything useful',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.notes_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BlocBuilder<BillBloc, BillState>(
        buildWhen: (a, b) => a.isBusy != b.isBusy,
        builder: (context, state) => AppFormActionBar(
          child: PrimaryButton(
            onPressed: state.isBusy ? null : _save,
            isLoading: state.isBusy,
            icon: _isEditing ? Icons.check_rounded : Icons.add_rounded,
            label: _isEditing ? 'Save changes' : 'Add bill',
          ),
        ),
      ),
    );
  }

  /// What "More options" holds, as its current values.
  String _moreOptionsSummary() => [
    _selectedCategory.label,
    _isRecurring ? _recurrenceSummary() : 'One-time',
    !_reminderEnabled
        ? 'No reminder'
        : _reminderHasPassed
        ? 'Reminder time passed'
        : _reminderSummary(),
  ].join(' · ');

  /// Whether the reminder as set falls before now, so it is never sent (the
  /// scheduler skips past times). Same time as [BillEntity.reminderDateTime]:
  /// the due time, else 9:00, that many days before the due date.
  bool get _reminderHasPassed {
    final due = _dueDate;
    if (!_reminderEnabled || due == null) return false;
    final day = due.addDays(-_reminderOffsetDays);
    final time = _dueTime ?? const TimeOfDay(hour: 9, minute: 0);
    return DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    ).isBefore(DateTime.now());
  }

  Widget _buildBudgetPicker(ThemeData theme) {
    if (_loadingBudgets) {
      return const Shimmer(
        child: SkeletonBox(height: 56, radius: AppSpacing.radiusMd),
      );
    }
    if (_budgetsFailed) {
      return StatusCard(
        color: theme.colorScheme.error,
        icon: Icons.error_outline_rounded,
        message: _budgetId == null
            ? "Couldn't load your budgets."
            : "Couldn't load your budgets. The bill keeps its budget.",
        trailing: TextButton(
          onPressed: _loadBudgets,
          child: const Text('Retry'),
        ),
      );
    }

    final today = DateTime.now();
    final options = BillBudgetLink.pickerOptions(
      _budgets,
      currentId: _original?.budgetId,
      today: today,
    );
    if (options.isEmpty) {
      return AppNotice(
        key: const ValueKey('billBudgetPickerEmpty'),
        tone: AppTone.info,
        icon: Icons.account_balance_wallet_outlined,
        title: 'No budget to link',
        message:
            'No budget is running or upcoming. You can link this bill later.',
      );
    }

    final selected = options.any((b) => b.id == _budgetId) ? _budgetId : null;
    final selectedBudget = selected == null
        ? null
        : options.firstWhere((b) => b.id == selected);
    // A link kept from before the budget's currency changed.
    final mismatch =
        selectedBudget != null && selectedBudget.currency != _currency;
    final helper = selectedBudget == null
        ? BillBudgetLink.pickerHelper
        : mismatch
        ? '${selectedBudget.name} uses ${selectedBudget.currency}, so this '
              "bill isn't set aside until it's in ${selectedBudget.currency}."
        : _currencyNote ?? BillBudgetLink.pickerHelper;
    return DropdownButtonFormField<String?>(
      key: ValueKey('billBudgetPicker_$_pickerResets'),
      value: selected,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Paid from',
        prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
        helperText: helper,
        helperMaxLines: 2,
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text(BillBudgetLink.notLinked),
        ),
        for (final b in options)
          DropdownMenuItem<String?>(
            value: b.id,
            child: Text(
              '${BillBudgetLink.budgetLabel(b, today)} · '
              '${formatShortDateRange(b.startDate, b.endDate)} · ${b.currency}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      selectedItemBuilder: (context) => [
        const Text(BillBudgetLink.notLinked),
        for (final b in options)
          Text(
            BillBudgetLink.budgetLabel(b, today),
            overflow: TextOverflow.ellipsis,
          ),
      ],
      onChanged: _onBudgetPicked,
    );
  }

  String _dueLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.addDays(1)) return 'Tomorrow';
    return DateFormat('EEE, d MMM yyyy').format(date);
  }

  String _unitLabel() {
    final plural = _recurrenceInterval != 1;
    return switch (_recurrenceType) {
      RecurrenceType.weekly => plural ? 'weeks' : 'week',
      RecurrenceType.monthly => plural ? 'months' : 'month',
      RecurrenceType.yearly => plural ? 'years' : 'year',
      RecurrenceType.none => '',
    };
  }

  String _recurrenceSummary() {
    if (_recurrenceInterval == 1) return _recurrenceType.label;
    return 'Every $_recurrenceInterval ${_unitLabel()}';
  }

  String _reminderSummary() => switch (_reminderOffsetDays) {
    0 => 'On the due date',
    1 => '1 day before',
    7 => '1 week before',
    final d => '$d days before',
  };
}

/// A switch, and under it the options it turns on, revealed as it is
/// switched on.
class _ToggleSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget child;

  const _ToggleSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          value: value,
          onChanged: onChanged,
        ),
        AppAnimatedSize(
          duration: AppMotion.respectReducedMotion(context, AppMotion.standard),
          curve: AppMotion.standardCurve,
          alignment: Alignment.topCenter,
          child: !value
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.xxl - AppSpacing.sm,
                    bottom: AppSpacing.sm,
                  ),
                  child: child,
                ),
        ),
      ],
    );
  }
}

/// How often a bill repeats: weekly, monthly or yearly, every N of them.
class _RepeatOptions extends StatelessWidget {
  final RecurrenceType type;
  final ValueChanged<RecurrenceType> onTypeChanged;
  final TextEditingController intervalController;
  final ValueChanged<String> onIntervalChanged;
  final String unitLabel;
  final String? intervalError;

  const _RepeatOptions({
    required this.type,
    required this.onTypeChanged,
    required this.intervalController,
    required this.onIntervalChanged,
    required this.unitLabel,
    required this.intervalError,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<RecurrenceType>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: RecurrenceType.weekly, label: Text('Weekly')),
            ButtonSegment(
              value: RecurrenceType.monthly,
              label: Text('Monthly'),
            ),
            ButtonSegment(value: RecurrenceType.yearly, label: Text('Yearly')),
          ],
          selected: {type},
          onSelectionChanged: (s) => onTypeChanged(s.first),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            // The field is labelled as a whole, so "Every" and the unit
            // are not read again around it.
            ExcludeSemantics(
              child: Text('Every', style: theme.textTheme.bodyMedium),
            ),
            const SizedBox(width: AppSpacing.sm),
            // At least 64 dp, wider when large text needs it.
            ConstrainedBox(
              key: const Key('billIntervalField'),
              constraints: const BoxConstraints(minWidth: 64),
              child: IntrinsicWidth(
                child: Semantics(
                  label: 'Repeat every … $unitLabel',
                  child: TextField(
                    controller: intervalController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.smd,
                      ),
                      enabledBorder: intervalError == null
                          ? null
                          : theme.inputDecorationTheme.errorBorder,
                    ),
                    onChanged: onIntervalChanged,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: ExcludeSemantics(
                child: Text(unitLabel, style: theme.textTheme.bodyMedium),
              ),
            ),
          ],
        ),
        if (intervalError != null) FormFieldError(message: intervalError!),
      ],
    );
  }
}

/// When the reminder comes, in days before the due date, and a note when
/// that time [hasPassed].
class _ReminderOffsets extends StatelessWidget {
  final int selected;
  final bool hasPassed;
  final ValueChanged<int> onSelected;

  const _ReminderOffsets({
    required this.selected,
    required this.hasPassed,
    required this.onSelected,
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
            for (final (days, label) in const [
              (0, 'On the day'),
              (1, '1 day before'),
              (2, '2 days before'),
              (3, '3 days before'),
              (7, '1 week before'),
            ])
              ChoiceChip(
                label: Text(label),
                selected: selected == days,
                onSelected: (_) => onSelected(days),
              ),
          ],
        ),
        if (hasPassed)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              "This reminder time has passed, so it won't be sent.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _PickerField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final String? hint;
  final String? errorText;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _PickerField({
    required this.label,
    required this.icon,
    required this.value,
    this.hint,
    this.errorText,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // One node: the error is part of its label, and Clear, otherwise hidden
    // inside it, is a custom action.
    return Semantics(
      button: true,
      label: [label, value, ?errorText].join(', '),
      onTap: onTap,
      customSemanticsActions: onClear == null
          ? null
          : {const CustomSemanticsAction(label: 'Clear'): onClear!},
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusMd,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            errorText: errorText,
            helperText: hint,
            suffixIcon: onClear == null
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: onClear,
                  ),
          ),
          child: Text(
            value,
            style: theme.textTheme.bodyLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// The currency of a bill not linked to a budget: the code once chosen,
/// symbol and code in the menu.
class _CurrencyPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _CurrencyPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final byCode = <String, CurrencyEntity>{
      for (final c in availableCurrencies.reversed) c.code: c,
    };
    final currencies = byCode.values.toList().reversed.toList();
    // A plain dropdown in the field's frame: the form's one
    // DropdownButtonFormField<String?> stays the budget picker.
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Currency',
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.smd),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: byCode.containsKey(value) ? value : null,
          isExpanded: true,
          items: [
            for (final c in currencies)
              DropdownMenuItem(
                value: c.code,
                child: Text('${c.symbol}  ${c.code}'),
              ),
          ],
          selectedItemBuilder: (context) => [
            for (final c in currencies) Text(c.code),
          ],
          onChanged: (code) {
            if (code != null) onChanged(code);
          },
        ),
      ),
    );
  }
}
