import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/di/injection.dart';
import '../../../settings/domain/entities/settings_failure.dart';
import '../../../settings/domain/usecases/load_settings_usecase.dart';
import '../../domain/entities/bill_entity.dart';
import '../../domain/entities/bill_enums.dart';
import '../bloc/bill_bloc.dart';
import '../bloc/bill_event.dart';
import '../bloc/bill_state.dart';

/// Add/Edit bill form screen.
class BillFormScreen extends StatefulWidget {
  final String? billId;

  const BillFormScreen({super.key, this.billId});

  @override
  State<BillFormScreen> createState() => _BillFormScreenState();
}

class _BillFormScreenState extends State<BillFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _titleError;
  String? _amountError;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  BillCategory _selectedCategory = BillCategory.other;
  bool _isRecurring = false;
  RecurrenceType _recurrenceType = RecurrenceType.monthly;
  int _recurrenceInterval = 1;
  bool _reminderEnabled = true;
  int _reminderOffsetDays = 1;
  String _currency = 'INR';

  bool get _isEditing => widget.billId != null;

  @override
  void initState() {
    super.initState();
    _loadCurrency();
    if (_isEditing) {
      context.read<BillBloc>().add(BillLoadById(widget.billId!));
    }
  }

  Future<void> _loadCurrency() async {
    try {
      final loadSettings = getIt<LoadSettingsUseCase>();
      final result = await loadSettings();
      if (result case SettingsSuccess(:final data)) {
        if (mounted) {
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
    super.dispose();
  }

  void _populateFromBill(BillEntity bill) {
    _titleController.text = bill.title;
    _amountController.text = bill.amount.toString();
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
    _recurrenceType = bill.recurrenceType;
    _recurrenceInterval = bill.recurrenceInterval;
    _reminderEnabled = bill.reminderEnabled;
    _reminderOffsetDays = bill.reminderOffsetDays;
    _currency = bill.currency;
  }

  void _onTitleChanged(String value) {
    setState(() {
      _titleError = null;
    });
  }

  void _onAmountChanged(String value) {
    setState(() {
      _amountError = null;
    });
  }

  void _save() {
    FocusManager.instance.primaryFocus?.unfocus();

    // Validate.
    final titleError = _validateTitle();
    final amountError = _validateAmount();

    setState(() {
      _titleError = titleError;
      _amountError = amountError;
    });

    if (titleError != null || amountError != null) return;
    if (_dueDate == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please select a due date')),
        );
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
      isPaid: false,
      createdAt: _isEditing ? now : now,
      updatedAt: now,
    );

    if (_isEditing) {
      context.read<BillBloc>().add(BillUpdate(bill));
    } else {
      context.read<BillBloc>().add(BillCreate(bill));
    }
  }

  String? _validateTitle() {
    if (_titleController.text.trim().isEmpty) {
      return 'Bill name cannot be empty';
    }
    if (_titleController.text.trim().length > 100) {
      return 'Bill name is too long';
    }
    return null;
  }

  String? _validateAmount() {
    if (_amountController.text.trim().isEmpty) {
      return 'Amount cannot be empty';
    }
    final value = double.tryParse(_amountController.text.trim());
    if (value == null) {
      return 'Please enter a valid number';
    }
    if (value <= 0) {
      return 'Amount must be greater than zero';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Bill' : 'Add Bill')),
      body: BlocConsumer<BillBloc, BillState>(
        listener: (context, state) {
          if (state.isBusy) return;

          if (state.status == BillBlocStatus.success) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.message ?? 'Saved')));
            context.read<BillBloc>().add(const BillClearMessage());
            context.pop();
          } else if (state.status == BillBlocStatus.error) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.message ?? 'Something went wrong'),
                  backgroundColor: AppColors.dangerRed,
                ),
              );
            context.read<BillBloc>().add(const BillClearMessage());
          }

          // Populate fields when editing and bill loaded.
          if (state.selectedBill != null &&
              _isEditing &&
              _titleController.text.isEmpty) {
            _populateFromBill(state.selectedBill!);
          }
        },
        builder: (context, state) {
          if (_isEditing && state.status == BillBlocStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Bill Name
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Bill Name',
                      hintText: 'e.g. Rent, Electricity, Netflix',
                      prefixIcon: const Icon(Icons.receipt_long_rounded),
                      errorText: _titleError,
                    ),
                    textCapitalization: TextCapitalization.words,
                    onChanged: _onTitleChanged,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Amount
                  TextFormField(
                    controller: _amountController,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      hintText: '0.00',
                      prefixIcon: const Icon(Icons.attach_money_rounded),
                      prefixText: '${CurrencyFormatter.symbolFor(_currency)} ',
                      errorText: _amountError,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: _onAmountChanged,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Category
                  DropdownButtonFormField<BillCategory>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_rounded),
                    ),
                    items: BillCategory.values
                        .map(
                          (cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedCategory = value);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Due Date
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_rounded),
                    title: const Text('Due Date'),
                    subtitle: Text(
                      _dueDate != null
                          ? DateFormat('EEE, MMM d, yyyy').format(_dueDate!)
                          : 'Tap to select',
                      style: TextStyle(
                        color: _dueDate != null
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => _dueDate = picked);
                      }
                    },
                  ),
                  const Divider(),

                  // Due Time (optional)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time_rounded),
                    title: const Text('Due Time'),
                    subtitle: Text(
                      _dueTime != null
                          ? _dueTime!.format(context)
                          : 'Optional - defaults to 9:00 AM',
                      style: TextStyle(
                        color: _dueTime != null
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    trailing: _dueTime != null
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () => setState(() => _dueTime = null),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime:
                            _dueTime ?? const TimeOfDay(hour: 9, minute: 0),
                      );
                      if (picked != null) {
                        setState(() => _dueTime = picked);
                      }
                    },
                  ),
                  const Divider(),
                  const SizedBox(height: AppSpacing.sm),

                  // Note
                  TextFormField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      hintText: 'Optional note...',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Recurring toggle
                  SwitchListTile(
                    title: const Text('Repeat this bill'),
                    subtitle: Text(
                      _isRecurring
                          ? '${_recurrenceType.label}${_recurrenceInterval > 1 ? ' (every $_recurrenceInterval)' : ''}'
                          : 'One-time bill',
                    ),
                    value: _isRecurring,
                    onChanged: (value) => setState(() => _isRecurring = value),
                    contentPadding: EdgeInsets.zero,
                  ),

                  // Recurrence options (visible when recurring is on)
                  if (_isRecurring) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<RecurrenceType>(
                            value: _recurrenceType,
                            decoration: const InputDecoration(
                              labelText: 'Frequency',
                              isDense: true,
                            ),
                            items:
                                [
                                      RecurrenceType.weekly,
                                      RecurrenceType.monthly,
                                      RecurrenceType.yearly,
                                    ]
                                    .map(
                                      (type) => DropdownMenuItem(
                                        value: type,
                                        child: Text(type.label),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _recurrenceType = value);
                              }
                            },
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              const Text('Every'),
                              const SizedBox(width: AppSpacing.sm),
                              SizedBox(
                                width: 60,
                                child: TextFormField(
                                  initialValue: '1',
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
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
                                      setState(() => _recurrenceInterval = n);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                _recurrenceType.label.toLowerCase() == 'weekly'
                                    ? _recurrenceInterval == 1
                                          ? 'week'
                                          : 'weeks'
                                    : _recurrenceType.label.toLowerCase() ==
                                          'monthly'
                                    ? _recurrenceInterval == 1
                                          ? 'month'
                                          : 'months'
                                    : _recurrenceInterval == 1
                                    ? 'year'
                                    : 'years',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),

                  // Reminder toggle
                  SwitchListTile(
                    title: const Text('Remind me'),
                    subtitle: Text(
                      _reminderEnabled
                          ? _reminderOffsetDays == 0
                                ? 'On the due date'
                                : '$_reminderOffsetDays day${_reminderOffsetDays > 1 ? 's' : ''} before'
                          : 'No reminder',
                    ),
                    value: _reminderEnabled,
                    onChanged: (value) =>
                        setState(() => _reminderEnabled = value),
                    contentPadding: EdgeInsets.zero,
                  ),

                  // Reminder offset (visible when reminder is on)
                  if (_reminderEnabled) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xl),
                      child: DropdownButtonFormField<int>(
                        value: _reminderOffsetDays,
                        decoration: const InputDecoration(
                          labelText: 'Remind me',
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 0,
                            child: Text('On the due date'),
                          ),
                          const DropdownMenuItem(
                            value: 1,
                            child: Text('1 day before'),
                          ),
                          const DropdownMenuItem(
                            value: 2,
                            child: Text('2 days before'),
                          ),
                          const DropdownMenuItem(
                            value: 3,
                            child: Text('3 days before'),
                          ),
                          const DropdownMenuItem(
                            value: 7,
                            child: Text('1 week before'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _reminderOffsetDays = value);
                          }
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),

                  // Save button
                  FilledButton(
                    onPressed: state.isBusy ? null : _save,
                    child: state.isBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isEditing ? 'Update Bill' : 'Add Bill'),
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
}
