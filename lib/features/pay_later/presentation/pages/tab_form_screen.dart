import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/dates/calendar_dates.dart';
import '../../../../core/feedback/app_haptics.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/app_animated_size.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_form_action_bar.dart';
import '../../../../core/widgets/app_page_body.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../expenses/presentation/widgets/form_field_error.dart';
import '../../../settings/domain/entities/currency_entity.dart';
import '../../../settings/presentation/widgets/currency_selector.dart';
import '../../domain/entities/pay_later_tab.dart';
import '../../domain/entities/settle_rhythm.dart';
import '../bloc/tab_form_cubit.dart';
import '../bloc/tab_form_state.dart';
import '../widgets/tab_visuals.dart';

/// How the settle-up rhythm is chosen in the form.
enum _RhythmChoice {
  onDemand('On demand'),
  every7('Every 7 days'),
  every14('Every 14 days'),
  every21('Every 21 days'),
  every30('Every 30 days'),
  customDays('Custom days'),
  monthly('Monthly on a day'),
  pickDate('Pick a date');

  final String label;
  const _RhythmChoice(this.label);

  int? get presetDays => switch (this) {
    every7 => 7,
    every14 => 14,
    every21 => 21,
    every30 => 30,
    _ => null,
  };

  bool get isEveryDays => presetDays != null || this == customDays;

  static _RhythmChoice of(SettleRhythm rhythm) => switch (rhythm) {
    OnDemand() => onDemand,
    EveryDays(:final days) => switch (days) {
      7 => every7,
      14 => every14,
      21 => every21,
      30 => every30,
      _ => customDays,
    },
    MonthlyDay() => monthly,
    ManualDate() => pickDate,
  };
}

/// Add/Edit a Pay Later tab. The create route pops the new tab's id.
class TabFormScreen extends StatefulWidget {
  /// Null when creating.
  final String? tabId;

  /// Currency a new tab starts with (query parameter), else the active
  /// budget's.
  final String? currency;

  const TabFormScreen({super.key, this.tabId, this.currency});

  @override
  State<TabFormScreen> createState() => _TabFormScreenState();
}

class _TabFormScreenState extends State<TabFormScreen> {
  bool get _isEditing => widget.tabId != null;

  @override
  void initState() {
    super.initState();
    context.read<TabFormCubit>().load(
      tabId: widget.tabId,
      currencyQuery: widget.currency,
    );
  }

  void _close([String? createdId]) {
    if (context.canPop()) {
      context.pop(createdId);
    } else {
      context.go(AppRouter.payLaterPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit tab' : 'New tab'),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: _close,
        ),
      ),
      body: BlocConsumer<TabFormCubit, TabFormState>(
        listenWhen: (a, b) => a.saved != b.saved || a.saveError != b.saveError,
        listener: (context, state) {
          final saved = state.saved;
          if (saved != null) {
            AppHaptics.confirm();
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(_isEditing ? 'Tab saved' : 'Tab added')),
              );
            _close(_isEditing ? null : saved.id);
          } else if (state.saveError != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.saveError!)));
          }
        },
        builder: (context, state) {
          switch (state.status) {
            case TabFormStatus.loading:
              return const FormSkeleton(rows: 6);
            case TabFormStatus.notFound:
            case TabFormStatus.loadFailed:
              return Center(
                child: Padding(
                  padding: AppSpacing.pagePadding,
                  child: Text(
                    state.status == TabFormStatus.notFound
                        ? 'Tab not found'
                        : TabFormCubit.loadFailedMessage,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            case TabFormStatus.ready:
              return _TabForm(state: state);
          }
        },
      ),
    );
  }
}

class _TabForm extends StatefulWidget {
  final TabFormState state;

  const _TabForm({required this.state});

  @override
  State<_TabForm> createState() => _TabFormState();
}

class _TabFormState extends State<_TabForm> {
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _note = TextEditingController();
  final _customDays = TextEditingController(text: '10');
  final _monthlyDay = TextEditingController(text: '1');

  String? _nameError;
  String? _daysError;
  String? _dayError;
  PayLaterTabCategory _category = PayLaterTabCategory.other;
  late String _currency;
  _RhythmChoice _rhythm = _RhythmChoice.onDemand;
  DateTime _anchor = DateTime.now().dateOnly;
  DateTime? _settleDate;
  DateTime? _manualAnchor;
  String? _defaultCategoryId;
  bool _reminderEnabled = false;

  /// Why no reminder can be set with the chosen rhythm (spec §8: none on
  /// demand, none without a settle-up day), or null when one can.
  String? get _reminderUnavailable => switch (_rhythm) {
    _RhythmChoice.onDemand =>
      'On demand has no settle-up day to remind you about.',
    _RhythmChoice.pickDate when _settleDate == null =>
      'Pick a settle-up date to get a reminder.',
    _ => null,
  };

  /// The reminder as shown and saved: never on when it could never fire.
  /// The user's choice is kept, so it comes back with a rhythm that has a
  /// settle-up day.
  bool get _reminderOn => _reminderEnabled && _reminderUnavailable == null;
  int _reminderOffset = 0;

  PayLaterTab? get _original => widget.state.original;

  @override
  void initState() {
    super.initState();
    final original = _original;
    _currency = widget.state.defaultCurrency;
    if (original == null) return;
    _name.text = original.name;
    _contact.text = original.contact ?? '';
    _note.text = original.note ?? '';
    _category = original.category;
    _currency = original.currency;
    _defaultCategoryId = original.defaultCategoryId;
    _reminderEnabled = original.reminderEnabled;
    _reminderOffset = original.reminderOffsetDays;
    _rhythm = _RhythmChoice.of(original.rhythm);
    switch (original.rhythm) {
      case EveryDays(:final days, :final anchor):
        _customDays.text = '$days';
        _anchor = anchor;
      case MonthlyDay(:final day):
        _monthlyDay.text = '$day';
      case ManualDate(:final nextSettleDate, :final anchor):
        _settleDate = nextSettleDate;
        _manualAnchor = anchor;
      case OnDemand():
        break;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _note.dispose();
    _customDays.dispose();
    _monthlyDay.dispose();
    super.dispose();
  }

  SettleRhythm? _buildRhythm() {
    _daysError = null;
    _dayError = null;
    switch (_rhythm) {
      case _RhythmChoice.onDemand:
        return const OnDemand();
      case _RhythmChoice.monthly:
        final day = int.tryParse(_monthlyDay.text.trim());
        if (day == null || day < 1 || day > 31) {
          _dayError = 'Choose a day of the month from 1 to 31.';
          return null;
        }
        return MonthlyDay(day: day);
      case _RhythmChoice.pickDate:
        return ManualDate(nextSettleDate: _settleDate, anchor: _manualAnchor);
      case _RhythmChoice.customDays:
        final days = int.tryParse(_customDays.text.trim());
        if (days == null || days < 1 || days > 365) {
          _daysError = 'Enter a number of days from 1 to 365.';
          return null;
        }
        return EveryDays(days: days, anchor: _anchor);
      default:
        return EveryDays(days: _rhythm.presetDays!, anchor: _anchor);
    }
  }

  void _save() {
    final name = _name.text.trim();
    setState(() {
      _nameError = name.isEmpty || name.length > 100
          ? 'Enter a name of 1 to 100 characters.'
          : null;
    });
    final rhythm = _buildRhythm();
    if (_nameError != null || rhythm == null) {
      setState(() {});
      return;
    }
    final original = _original;
    final now = DateTime.now();
    String? orNull(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : t;
    }

    context.read<TabFormCubit>().save(
      PayLaterTab(
        id: original?.id ?? const Uuid().v4(),
        name: name,
        category: _category,
        currency: _currency,
        note: orNull(_note),
        contact: orNull(_contact),
        defaultCategoryId: _defaultCategoryId,
        rhythm: rhythm,
        reminderEnabled: _reminderOn,
        reminderOffsetDays: _reminderOffset,
        isArchived: original?.isArchived ?? false,
        createdAt: original?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  void _pickCurrency() {
    AppBottomSheet.show<void>(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppSheetHeader(
            title: 'Currency',
            subtitle: "Fixed once the tab has purchases or payments.",
          ),
          // The selector closes its own sheet after a pick; popping here
          // too would close this form as well.
          CurrencySelector(
            selectedCode: _currency,
            onSelected: (CurrencyEntity c) =>
                setState(() => _currency = c.code),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Future<void> _pickDate({
    required DateTime? current,
    required DateTime first,
    required String help,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now().dateOnly;
    final initial = current ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(now.year + 10, 12, 31),
      helpText: help,
    );
    if (picked != null && mounted) setState(() => onPicked(picked.dateOnly));
  }

  String _date(DateTime d) => DateFormat.yMMMd().format(d);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final locked = state.hasActivity;
    final today = DateTime.now().dateOnly;
    final categories = state.categories
        .where((c) => !c.isArchived || c.id == _defaultCategoryId)
        .toList();
    final defaultCategoryValue =
        categories.any((c) => c.id == _defaultCategoryId)
        ? _defaultCategoryId
        : null;

    return Column(
      children: [
        Expanded(
          child: AppPageBody(
            builder: (context, padding) => ListView(
              // The save bar below clears the home indicator.
              padding: padding.copyWith(bottom: AppSpacing.md),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                TextFormField(
                  key: const Key('tabNameField'),
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Tab name',
                    hintText: 'e.g. Cafeteria, Corner shop',
                    prefixIcon: const Icon(Icons.storefront_outlined),
                    errorText: _nameError,
                  ),
                  onChanged: (_) {
                    if (_nameError != null) setState(() => _nameError = null);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Type', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final c in PayLaterTabCategory.values)
                      ChoiceChip(
                        key: Key('tabCategory_${c.key}'),
                        selected: _category == c,
                        showCheckmark: false,
                        avatar: Icon(
                          tabCategoryIcon(c),
                          size: AppSizes.iconSm + 2,
                        ),
                        label: Text(_categoryLabel(c)),
                        onSelected: (_) => setState(() => _category = c),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _PickerField(
                  key: const Key('tabCurrencyField'),
                  label: 'Currency',
                  icon: Icons.payments_outlined,
                  value: '${CurrencyFormatter.symbolFor(_currency)} $_currency',
                  hint: locked
                      ? "Locked: this tab has purchases or payments."
                      : null,
                  onTap: locked ? null : _pickCurrency,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<_RhythmChoice>(
                  key: const Key('tabRhythmPicker'),
                  value: _rhythm,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'When you settle up',
                    prefixIcon: Icon(Icons.event_repeat_outlined),
                  ),
                  items: [
                    for (final r in _RhythmChoice.values)
                      DropdownMenuItem(
                        key: Key('tabRhythm_${r.name}'),
                        value: r,
                        child: Text(r.label),
                      ),
                  ],
                  onChanged: (r) {
                    if (r != null) {
                      setState(() {
                        _rhythm = r;
                        _daysError = null;
                        _dayError = null;
                      });
                    }
                  },
                ),
                AppAnimatedSize(
                  duration: AppMotion.respectReducedMotion(
                    context,
                    AppMotion.standard,
                  ),
                  curve: AppMotion.standardCurve,
                  alignment: Alignment.topCenter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_rhythm == _RhythmChoice.customDays) ...[
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          key: const Key('tabCustomDaysField'),
                          controller: _customDays,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Number of days',
                            helperText: 'From 1 to 365',
                            errorText: _daysError,
                          ),
                          onChanged: (_) {
                            if (_daysError != null) {
                              setState(() => _daysError = null);
                            }
                          },
                        ),
                      ],
                      if (_rhythm == _RhythmChoice.monthly) ...[
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          key: const Key('tabMonthlyDayField'),
                          controller: _monthlyDay,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Day of the month',
                            helperText:
                                'From 1 to 31; short months use their last day',
                            errorText: _dayError,
                          ),
                          onChanged: (_) {
                            if (_dayError != null) {
                              setState(() => _dayError = null);
                            }
                          },
                        ),
                      ],
                      if (_rhythm.isEveryDays) ...[
                        const SizedBox(height: AppSpacing.md),
                        _PickerField(
                          key: const Key('tabAnchorField'),
                          label: 'First period starts',
                          icon: Icons.flag_outlined,
                          value: _date(_anchor),
                          onTap: () => _pickDate(
                            current: _anchor,
                            first: DateTime(today.year - 5),
                            help: 'First period starts',
                            onPicked: (d) => _anchor = d,
                          ),
                        ),
                      ],
                      if (_rhythm == _RhythmChoice.pickDate) ...[
                        const SizedBox(height: AppSpacing.md),
                        _PickerField(
                          key: const Key('tabSettleDateField'),
                          label: 'Settle-up date',
                          icon: Icons.event_outlined,
                          value: _settleDate == null
                              ? 'Not set'
                              : _date(_settleDate!),
                          onTap: () => _pickDate(
                            current: _settleDate,
                            first: _original == null || _settleDate == null
                                ? today
                                : (_settleDate!.isBefore(today)
                                      ? _settleDate!
                                      : today),
                            help: 'Settle-up date',
                            onPicked: (d) => _settleDate = d,
                          ),
                          onClear: _settleDate == null
                              ? null
                              : () => setState(() => _settleDate = null),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _ToggleSection(
                  icon: Icons.notifications_outlined,
                  title: 'Remind me',
                  subtitle: _reminderUnavailable ?? 'Before the settle-up day',
                  value: _reminderOn,
                  onChanged: _reminderUnavailable != null
                      ? null
                      : (v) => setState(() => _reminderEnabled = v),
                  child: DropdownButtonFormField<int>(
                    key: const Key('tabReminderOffset'),
                    value: _reminderOffset,
                    decoration: const InputDecoration(labelText: 'Remind me'),
                    items: [
                      for (var d = 0; d <= 7; d++)
                        DropdownMenuItem(
                          value: d,
                          child: Text(_offsetLabel(d)),
                        ),
                    ],
                    onChanged: (d) {
                      if (d != null) setState(() => _reminderOffset = d);
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String?>(
                  key: const Key('tabDefaultCategory'),
                  value: defaultCategoryValue,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Default expense category',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('None'),
                    ),
                    for (final c in categories)
                      DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text(c.name),
                      ),
                  ],
                  onChanged: (id) => setState(() => _defaultCategoryId = id),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('tabContactField'),
                  controller: _contact,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Contact',
                    hintText: 'Phone, person or place',
                    prefixIcon: Icon(Icons.contact_phone_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('tabNoteField'),
                  controller: _note,
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                if (_daysError != null && _rhythm != _RhythmChoice.customDays)
                  FormFieldError(message: _daysError!),
              ],
            ),
          ),
        ),
        // The body already sits above the keyboard, so the bar's keyboard
        // padding is zero here; it keeps the safe area and the tablet width.
        AppFormActionBar(
          child: PrimaryButton(
            key: const Key('tabSaveButton'),
            onPressed: state.saving ? null : _save,
            isLoading: state.saving,
            icon: _original == null ? Icons.add_rounded : Icons.check_rounded,
            label: _original == null ? 'Add tab' : 'Save changes',
          ),
        ),
      ],
    );
  }

  static String _offsetLabel(int d) => switch (d) {
    0 => 'On the day',
    1 => '1 day before',
    7 => '1 week before',
    _ => '$d days before',
  };

  static String _categoryLabel(PayLaterTabCategory c) => switch (c) {
    PayLaterTabCategory.foodDining => 'Food and dining',
    PayLaterTabCategory.groceries => 'Groceries',
    PayLaterTabCategory.shopping => 'Shopping',
    PayLaterTabCategory.personal => 'Personal',
    PayLaterTabCategory.other => 'Other',
  };
}

/// A switch, and under it the options it turns on.
class _ToggleSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;

  /// Null disables the switch ([subtitle] then says why).
  final ValueChanged<bool>? onChanged;
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
          key: const Key('tabReminderSwitch'),
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

class _PickerField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final String? hint;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const _PickerField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    this.hint,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '$label, $value',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusMd,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            helperText: hint,
            enabled: onTap != null,
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
