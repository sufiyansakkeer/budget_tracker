import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/feedback/app_haptics.dart';
import '../../../../core/navigation/push_unique.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_amount_pad.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_list.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_notice.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/validators/expense_validator.dart';
import '../bloc/expense_bloc.dart';
import '../bloc/expense_event.dart';
import '../bloc/expense_state.dart';
import '../widgets/category_visuals.dart';
import '../widgets/expense_date_rules.dart';
import '../widgets/form_field_error.dart';
import 'amount_entry.dart';

enum _Day { today, yesterday, other }

/// Adds an expense in a few taps: the amount on a number pad, one of your
/// most used categories and the day. Everything else (note, budget, time,
/// tags, receipt) is one tap away in "More details", which opens the full
/// form with what was entered so far.
///
/// The expense goes to the active budget. Nothing is checked while typing;
/// tapping Add checks the amount, the category and that the day falls in
/// the budget's period, and says what is missing.
class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key});

  /// "Now" for the default day and time; replaced in tests.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  /// Opens the sheet over [context]. If the person asks for the full form
  /// (or to create a budget), that screen opens once the sheet has closed.
  static Future<void> show(BuildContext context) async {
    final route = await AppBottomSheet.show<String>(
      context: context,
      builder: (_) => BlocProvider(
        create: (_) => getIt<ExpenseBloc>(),
        child: const QuickAddSheet(),
      ),
    );
    if (route != null && context.mounted) context.pushUnique(route);
  }

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  late final DateTime _now = QuickAddSheet.clock();
  late AmountEntry _entry = AmountEntry.empty(null);
  String? _categoryId;
  _Day _day = _Day.today;
  late DateTime _otherDate = _today;

  String? _amountError;
  String? _categoryError;
  String? _dateError;
  String? _saveError;

  DateTime get _today => DateTime(_now.year, _now.month, _now.day);

  DateTime get _date => switch (_day) {
    _Day.today => _today,
    _Day.yesterday => DateTime(_now.year, _now.month, _now.day - 1),
    _Day.other => _otherDate,
  };

  @override
  void initState() {
    super.initState();
    context.read<ExpenseBloc>().add(ExpenseLoadQuickAdd(now: _now));
  }

  void _onKey(AmountPadKey key) {
    setState(() {
      _entry = switch (key) {
        DigitKey(:final digit) => _entry.digit(digit),
        DecimalKey() => _entry.decimal(),
        BackspaceKey() => _entry.backspace(),
      };
      _amountError = null;
    });
  }

  void _pickCategory(String id) {
    AppHaptics.selection();
    setState(() {
      _categoryId = id;
      _categoryError = null;
    });
  }

  void _pickDay(_Day day) {
    AppHaptics.selection();
    setState(() {
      _day = day;
      _dateError = null;
    });
  }

  Future<void> _pickOtherDay(BudgetEntity? budget) async {
    final firstDate = budget == null
        ? DateTime(_today.year - 1, _today.month, _today.day)
        : DateTime(
            budget.startDate.year,
            budget.startDate.month,
            budget.startDate.day,
          );
    // Never after today, nor after the budget ends.
    var lastDate = _today;
    if (budget != null && budget.endDate.isBefore(lastDate)) {
      lastDate = DateTime(
        budget.endDate.year,
        budget.endDate.month,
        budget.endDate.day,
      );
    }
    if (lastDate.isBefore(firstDate)) lastDate = firstDate;
    final initial = _date.isBefore(firstDate)
        ? firstDate
        : (_date.isAfter(lastDate) ? lastDate : _date);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Expense date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _otherDate = picked;
      _day = _isSameDay(picked, _today)
          ? _Day.today
          : _isSameDay(picked, _today.subtract(const Duration(days: 1)))
          ? _Day.yesterday
          : _Day.other;
      _dateError = null;
    });
  }

  Future<void> _pickFromAll(List<ExpenseCategory> categories) async {
    final id = await AppBottomSheet.show<String>(
      context: context,
      builder: (context) =>
          _AllCategoriesSheet(categories: categories, selectedId: _categoryId),
    );
    if (id != null && mounted) _pickCategory(id);
  }

  void _save(ExpenseState state) {
    final budget = state.quickAddBudget;
    if (budget == null) return;
    final amountError = _entry.value <= 0
        ? 'Enter an amount.'
        : ExpenseValidator.validateAmount(_entry.normalized);
    final categoryError = _categoryId == null ? 'Choose a category.' : null;
    final dateError = ExpenseDateRules.outsideBudget(_date, budget);
    setState(() {
      _amountError = amountError;
      _categoryError = categoryError;
      _dateError = dateError;
      _saveError = null;
    });
    if (amountError != null || categoryError != null || dateError != null) {
      return;
    }

    final now = QuickAddSheet.clock();
    final date = _date;
    context.read<ExpenseBloc>().add(
      ExpenseCreate(
        ExpenseEntity(
          id: const Uuid().v4(),
          budgetId: budget.id,
          amount: double.parse(_entry.normalized),
          categoryId: _categoryId!,
          date: date,
          time: DateTime(date.year, date.month, date.day, now.hour, now.minute),
          createdAt: now,
          updatedAt: now,
        ),
      ),
    );
  }

  /// The full form with what has been entered so far.
  String _moreDetailsRoute(BudgetEntity? budget) => Uri(
    path: '/app/expenses/add',
    queryParameters: {
      if (_entry.value > 0) 'amount': _entry.normalized,
      'category': ?_categoryId,
      'date': DateFormat('yyyy-MM-dd').format(_date),
      'budget': ?budget?.id,
    },
  ).toString();

  void _onState(BuildContext context, ExpenseState state) {
    if (state.status == ExpenseBlocStatus.success &&
        state.lastAction == ExpenseAction.created) {
      AppHaptics.confirm();
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Expense added'),
            duration: Duration(seconds: 3),
          ),
        );
    } else if (state.status == ExpenseBlocStatus.error &&
        state.message != null) {
      setState(() => _saveError = state.message);
      context.read<ExpenseBloc>().add(const ExpenseClearMessage());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExpenseBloc, ExpenseState>(
      listenWhen: (a, b) =>
          a.status != b.status || a.quickAddBudget != b.quickAddBudget,
      listener: (context, state) {
        final currency = state.quickAddBudget?.currency;
        final adapted = _entry.forCurrency(currency);
        if (adapted != _entry) setState(() => _entry = adapted);
        _onState(context, state);
      },
      builder: (context, state) {
        final budget = state.quickAddBudget;
        final loaded = state.quickAddLoad == QuickAddLoad.loaded;
        final noBudget = loaded && budget == null;
        final currency = budget?.currency;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSheetHeader(
                title: 'Add expense',
                subtitle: !loaded
                    ? ' '
                    : budget == null
                    ? 'No budget yet'
                    : 'To ${budget.name} · until '
                          '${DateFormat('d MMM').format(budget.endDate)}',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AmountDisplay(
                      entry: _entry,
                      currency: currency,
                      hasError: _amountError != null,
                    ),
                    if (_amountError != null)
                      Center(child: _CenteredError(message: _amountError!)),
                    const SizedBox(height: AppSpacing.md),
                    if (noBudget)
                      AppNotice(
                        tone: AppTone.caution,
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'No budget yet',
                        message: 'Create a budget before adding expenses.',
                        action: TextButton(
                          onPressed: () =>
                              Navigator.of(context).pop('/app/budgets/create'),
                          child: const Text('Create budget'),
                        ),
                      )
                    else ...[
                      _CategoryChoice(
                        loaded: loaded,
                        frequent: state.frequentCategories,
                        all: state.categories,
                        selectedId: _categoryId,
                        onSelected: _pickCategory,
                        onMore: () => _pickFromAll(state.categories),
                      ),
                      if (_categoryError != null)
                        FormFieldError(message: _categoryError!),
                      const SizedBox(height: AppSpacing.smd),
                      _DayChoice(
                        day: _day,
                        otherDate: _otherDate,
                        onDay: _pickDay,
                        onOther: () => _pickOtherDay(budget),
                      ),
                      if (_dateError != null)
                        FormFieldError(message: _dateError!),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    AppAmountPad(
                      showDecimal: _entry.allowsDecimal,
                      onKey: _onKey,
                      onClear: () => setState(() {
                        _entry = _entry.clear();
                        _amountError = null;
                      }),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_saveError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: FormFieldError(message: _saveError!),
                      ),
                    _Actions(
                      busy: state.isBusy,
                      canAdd: budget != null,
                      addLabel: state.isBusy
                          ? 'Adding…'
                          : _entry.value > 0
                          ? 'Add ${AppMoney.format(_entry.value, currency: currency)}'
                          : 'Add expense',
                      onAdd: () => _save(state),
                      onMoreDetails: () =>
                          Navigator.of(context).pop(_moreDetailsRoute(budget)),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// "More details" and Add. They share a row; with large text they stack,
/// Add first and full width, so neither label is cut short.
class _Actions extends StatelessWidget {
  final bool busy;
  final bool canAdd;
  final String addLabel;
  final VoidCallback onAdd;
  final VoidCallback onMoreDetails;

  const _Actions({
    required this.busy,
    required this.canAdd,
    required this.addLabel,
    required this.onAdd,
    required this.onMoreDetails,
  });

  @override
  Widget build(BuildContext context) {
    final add = FilledButton(
      key: const Key('quickAddSave'),
      onPressed: busy || !canAdd ? null : onAdd,
      child: Text(addLabel, textAlign: TextAlign.center),
    );
    final more = TextButton(
      key: const Key('quickAddMoreDetails'),
      onPressed: busy ? null : onMoreDetails,
      child: const Text('More details', textAlign: TextAlign.center),
    );
    if (MediaQuery.textScalerOf(context).scale(14) > 20) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          add,
          const SizedBox(height: AppSpacing.xs),
          more,
        ],
      );
    }
    return Row(
      children: [
        more,
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: add),
      ],
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The amount as typed, large and centred, with the currency symbol small
/// and muted beside it. Read aloud as it changes.
class _AmountDisplay extends StatelessWidget {
  final AmountEntry entry;
  final String? currency;
  final bool hasError;

  const _AmountDisplay({
    required this.entry,
    required this.currency,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typography = context.appTypography;
    final empty = entry.isEmpty;
    final color = hasError
        ? context.tone(AppTone.critical).accent
        : empty
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface;
    final spoken = empty
        ? 'Amount, empty'
        : 'Amount, ${AppMoney.format(entry.value, currency: currency)}';
    return Semantics(
      key: const Key('quickAddAmount'),
      liveRegion: true,
      label: spoken,
      excludeSemantics: true,
      child: SizedBox(
        height: 72,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  CurrencyFormatter.symbolFor(currency),
                  style: typography.moneyTitle.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  entry.display,
                  style: typography.moneyHero.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CenteredError extends StatelessWidget {
  final String message;

  const _CenteredError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}

/// The most used categories as chips, plus the one chosen from the full
/// list when it is not among them, and "All categories".
class _CategoryChoice extends StatelessWidget {
  final bool loaded;
  final List<ExpenseCategory> frequent;
  final List<ExpenseCategory> all;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback onMore;

  const _CategoryChoice({
    required this.loaded,
    required this.frequent,
    required this.all,
    required this.selectedId,
    required this.onSelected,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!loaded) {
      return Shimmer(
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final w in [88.0, 104.0, 72.0, 96.0, 80.0])
              SkeletonBox(width: w, height: 32, radius: AppSpacing.radiusSm),
          ],
        ),
      );
    }
    final shown = [...frequent];
    if (selectedId != null && !shown.any((c) => c.id == selectedId)) {
      for (final c in all) {
        if (c.id == selectedId) shown.add(c);
      }
    }
    return Semantics(
      container: true,
      label: 'Category',
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final c in shown)
            ChoiceChip(
              key: Key('quickCategory_${c.id}'),
              selected: c.id == selectedId,
              showCheckmark: false,
              avatar: Icon(
                CategoryVisuals.iconFor(c.icon),
                color: CategoryVisuals.adaptiveColor(context, c.colorHex),
              ),
              label: Text(c.name),
              onSelected: (_) => onSelected(c.id),
            ),
          ActionChip(
            key: const Key('quickCategory_all'),
            avatar: Icon(
              Icons.apps_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            label: const Text('More'),
            tooltip: 'All categories',
            onPressed: onMore,
          ),
        ],
      ),
    );
  }
}

class _DayChoice extends StatelessWidget {
  final _Day day;
  final DateTime otherDate;
  final ValueChanged<_Day> onDay;
  final VoidCallback onOther;

  const _DayChoice({
    required this.day,
    required this.otherDate,
    required this.onDay,
    required this.onOther,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Day',
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          ChoiceChip(
            key: const Key('quickDate_today'),
            selected: day == _Day.today,
            label: const Text('Today'),
            onSelected: (_) => onDay(_Day.today),
          ),
          ChoiceChip(
            key: const Key('quickDate_yesterday'),
            selected: day == _Day.yesterday,
            label: const Text('Yesterday'),
            onSelected: (_) => onDay(_Day.yesterday),
          ),
          ChoiceChip(
            key: const Key('quickDate_other'),
            selected: day == _Day.other,
            showCheckmark: false,
            avatar: const Icon(Icons.calendar_today_outlined),
            label: Text(
              day == _Day.other
                  ? DateFormat('EEE d MMM').format(otherDate)
                  : 'Other day',
            ),
            onSelected: (_) => onOther(),
          ),
        ],
      ),
    );
  }
}

/// Every category, for when the one needed is not a shortcut.
class _AllCategoriesSheet extends StatelessWidget {
  final List<ExpenseCategory> categories;
  final String? selectedId;

  const _AllCategoriesSheet({
    required this.categories,
    required this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = [
      for (final c in categories)
        if (!c.isArchived) c,
    ];
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSheetHeader(title: 'Choose a category'),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
                AppGroupedList(
                  dividerIndent: AppSizes.avatarSm + AppSpacing.smd,
                  children: [
                    for (final c in shown)
                      AppListRow(
                        key: Key('allCategory_${c.id}'),
                        leading: IconTile(
                          icon: CategoryVisuals.iconFor(c.icon),
                          color: CategoryVisuals.adaptiveColor(
                            context,
                            c.colorHex,
                          ),
                          size: AppSizes.avatarSm,
                        ),
                        title: c.name,
                        trailing: c.id == selectedId
                            ? Icon(
                                Icons.check_rounded,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(c.id),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
