import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../settings/domain/entities/settings_failure.dart';
import '../../../settings/domain/usecases/load_settings_usecase.dart';
import '../../domain/entities/bill_entity.dart';
import '../../domain/entities/bill_enums.dart';
import '../bloc/bill_bloc.dart';
import '../bloc/bill_event.dart';
import '../bloc/bill_state.dart';
import 'bill_widgets.dart';

/// Add/Edit bill form screen.
///
/// Order: what and how much → when it is due → repeat → reminder → note.
/// The save button is pinned to the bottom so it is never hidden behind
/// the keyboard.
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

  bool get _isEditing => widget.billId != null;

  @override
  void initState() {
    super.initState();
    _loadCurrency();
    if (_isEditing) {
      context.read<BillBloc>().add(BillLoadById(widget.billId!));
    } else {
      // New bills default to being due today so the form saves in one tap.
      final now = DateTime.now();
      _dueDate = DateTime(now.year, now.month, now.day);
    }
  }

  Future<void> _loadCurrency() async {
    try {
      final result = await getIt<LoadSettingsUseCase>()();
      if (result case SettingsSuccess(:final data)) {
        if (mounted && !_populated) {
          setState(() => _currency = data.currencyCode);
        }
      }
    } catch (_) {
      // Keep default.
    }
  }

  @override
  void dispose() {
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
      _amountController.text = bill.amount == bill.amount.roundToDouble()
          ? bill.amount.toStringAsFixed(0)
          : bill.amount.toStringAsFixed(2);
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
    });
  }

  String? _validateTitle() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return 'Give the bill a name.';
    if (title.length > 100) return 'Keep the name under 100 characters.';
    return null;
  }

  String? _validateAmount() {
    final text = _amountController.text.trim();
    if (text.isEmpty) return 'Enter the amount due.';
    final value = double.tryParse(text);
    if (value == null) return 'Enter a valid number.';
    if (value <= 0) return 'The amount must be greater than zero.';
    return null;
  }

  void _save() {
    FocusManager.instance.primaryFocus?.unfocus();

    final titleError = _validateTitle();
    final amountError = _validateAmount();
    final dueDateError = _dueDate == null ? 'Choose a due date.' : null;
    setState(() {
      _titleError = titleError;
      _amountError = amountError;
      _dueDateError = dueDateError;
    });
    if (titleError != null || amountError != null) return;
    if (dueDateError != null) {
      final ctx = _dueDateKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: AppMotion.medium,
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit bill' : 'Add bill'),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: _close,
        ),
      ),
      body: BlocConsumer<BillBloc, BillState>(
        listener: (context, state) {
          if (state.isBusy) return;
          if (state.status == BillBlocStatus.success) {
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.message ?? 'Saved')));
            context.read<BillBloc>().add(const BillClearMessage());
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
            child: ListView(
              padding: AppSpacing.pagePadding,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                // What
                TextFormField(
                  controller: _titleController,
                  autofocus: !_isEditing,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Bill name',
                    hintText: 'e.g. Rent, Electricity, Netflix',
                    prefixIcon: const Icon(Icons.receipt_long_outlined),
                    errorText: _titleError,
                  ),
                  onChanged: (_) {
                    if (_titleError != null) setState(() => _titleError = null);
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // How much
                TextFormField(
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
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    hintText: '0.00',
                    prefixText: '${CurrencyFormatter.symbolFor(_currency)} ',
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
                const SizedBox(height: AppSpacing.md),

                // Category
                DropdownButtonFormField<BillCategory>(
                  value: _selectedCategory,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(BillVisuals.iconFor(_selectedCategory)),
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
                    for (final cat in BillCategory.values) Text(cat.label),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

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

                // Repeat
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.repeat_rounded),
                  title: const Text('Repeat this bill'),
                  subtitle: Text(
                    _isRecurring ? _recurrenceSummary() : 'One-time bill',
                  ),
                  value: _isRecurring,
                  onChanged: (value) => setState(() => _isRecurring = value),
                ),
                AnimatedSize(
                  duration: AppMotion.respectReducedMotion(
                    context,
                    AppMotion.standard,
                  ),
                  curve: AppMotion.standardCurve,
                  alignment: Alignment.topCenter,
                  child: !_isRecurring
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.xxl - AppSpacing.sm,
                            bottom: AppSpacing.sm,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SegmentedButton<RecurrenceType>(
                                showSelectedIcon: false,
                                segments: const [
                                  ButtonSegment(
                                    value: RecurrenceType.weekly,
                                    label: Text('Weekly'),
                                  ),
                                  ButtonSegment(
                                    value: RecurrenceType.monthly,
                                    label: Text('Monthly'),
                                  ),
                                  ButtonSegment(
                                    value: RecurrenceType.yearly,
                                    label: Text('Yearly'),
                                  ),
                                ],
                                selected: {_recurrenceType},
                                onSelectionChanged: (s) =>
                                    setState(() => _recurrenceType = s.first),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  Text(
                                    'Every',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  SizedBox(
                                    width: 64,
                                    child: TextField(
                                      controller: _intervalController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(2),
                                      ],
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: AppSpacing.sm,
                                          vertical: AppSpacing.smd,
                                        ),
                                      ),
                                      onChanged: (value) {
                                        final n = int.tryParse(value);
                                        if (n != null && n >= 1) {
                                          setState(
                                            () => _recurrenceInterval = n,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Flexible(
                                    child: Text(
                                      _unitLabel(),
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                ),

                // Reminder
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('Remind me'),
                  subtitle: Text(
                    _reminderEnabled ? _reminderSummary() : 'No reminder',
                  ),
                  value: _reminderEnabled,
                  onChanged: (value) =>
                      setState(() => _reminderEnabled = value),
                ),
                AnimatedSize(
                  duration: AppMotion.respectReducedMotion(
                    context,
                    AppMotion.standard,
                  ),
                  curve: AppMotion.standardCurve,
                  alignment: Alignment.topCenter,
                  child: !_reminderEnabled
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.xxl - AppSpacing.sm,
                            bottom: AppSpacing.sm,
                          ),
                          child: Wrap(
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
                                  selected: _reminderOffsetDays == days,
                                  onSelected: (_) => setState(
                                    () => _reminderOffsetDays = days,
                                  ),
                                ),
                            ],
                          ),
                        ),
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
                    hintText: 'Account number, provider, anything useful',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BlocBuilder<BillBloc, BillState>(
        buildWhen: (a, b) => a.isBusy != b.isBusy,
        builder: (context, state) => SafeArea(
          minimum: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
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

  String _dueLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.add(const Duration(days: 1))) return 'Tomorrow';
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
    return Semantics(
      button: true,
      label: '$label, $value',
      child: ExcludeSemantics(
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
      ),
    );
  }
}
