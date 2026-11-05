import 'dart:async';

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
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../budget/presentation/start_next_period.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/validators/expense_validator.dart';
import '../bloc/expense_bloc.dart';
import '../bloc/expense_event.dart';
import '../bloc/expense_state.dart';
import '../widgets/category_visuals.dart';
import '../widgets/expense_date_rules.dart';
import '../widgets/expense_undo.dart';
import '../widgets/form_field_error.dart';
import 'amount_entry.dart';
import '../../../../core/dates/calendar_dates.dart';

enum _Day { today, yesterday, other }

/// Adds an expense in a few taps: the amount on a number pad, one of your
/// most used categories and the day. Everything else (note, budget, time,
/// tags, receipt) is one tap away in "More details", which opens the full
/// form with what was entered so far.
///
/// The expense goes to the active budget. Nothing is checked while typing;
/// tapping Add checks the amount, the category and that the day falls in
/// the budget's period, and says what is missing. A budget that has ended or
/// not started yet is said up front.
///
/// Once an amount or a category is entered, Back, a scrim tap or a swipe
/// down asks before throwing it away, as the full form does.
class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key});

  /// "Now" for the default day and time; replaced in tests.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  /// Whether a sheet is open, so a second tap (or the home-screen widget)
  /// never stacks another.
  static bool _open = false;

  /// Opens the sheet over [context] unless one is already open. If the
  /// person asks for the full form (or to create a budget), that screen
  /// opens once the sheet has closed.
  static Future<void> show(BuildContext context) async {
    if (_open) return;
    _open = true;
    final String? route;
    try {
      route = await AppBottomSheet.show<String>(
        context: context,
        // The sheet draws its own, so a swipe on it can ask first.
        showDragHandle: false,
        builder: (_) => BlocProvider(
          create: (_) => getIt<ExpenseBloc>(),
          child: const QuickAddSheet(),
        ),
      );
    } finally {
      _open = false;
    }
    if (route == null || !context.mounted) return;
    final nextAfter = Uri.parse(route).queryParameters['next'];
    if (nextAfter != null) {
      unawaited(StartNextPeriod.open(context, nextAfter));
    } else {
      context.pushUnique(route);
    }
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

  /// Leaving now would lose what was entered.
  bool get _hasInput => !_entry.isEmpty || _categoryId != null;

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
          : _isSameDay(picked, _today.addDays(-1))
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
        : ExpenseValidator.validateAmount(
            _entry.normalized,
            currency: budget.currency,
          );
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

  /// The full form's question, so both ways of adding ask alike.
  Future<void> _requestClose() async {
    final discard = await ConfirmationDialog.show(
      context: context,
      title: 'Discard this expense?',
      message: "What you entered hasn't been saved.",
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      icon: Icons.edit_off_outlined,
      isDestructive: true,
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  void _onState(BuildContext context, ExpenseState state) {
    if (state.status == ExpenseBlocStatus.success &&
        state.lastAction == ExpenseAction.created) {
      AppHaptics.confirm();
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      ExpenseUndo.offerAdded(
        messenger,
        state.expense!,
        currency: state.quickAddBudget?.currency,
        after: state.afterAdd,
      );
    } else if (state.status == ExpenseBlocStatus.error &&
        state.message != null) {
      setState(() => _saveError = state.message);
      context.read<ExpenseBloc>().add(const ExpenseClearMessage());
    }
  }

  bool _startsLater(BudgetEntity budget) => _today.isBefore(
    DateTime(
      budget.startDate.year,
      budget.startDate.month,
      budget.startDate.day,
    ),
  );

  /// Up front when the budget isn't running today: an ended one (until a
  /// day in its period is picked) and one not started yet.
  Widget? _periodNotice(BudgetEntity budget) {
    if (_startsLater(budget)) {
      return AppNotice(
        tone: AppTone.caution,
        icon: Icons.event_outlined,
        title:
            'Your ${budget.name} budget starts on '
            '${DateFormat('d MMM').format(budget.startDate)}',
        message: 'You can add expenses to it from that day.',
      );
    }
    if (budget.isActiveOn(_today) || budget.isActiveOn(_date)) return null;
    return AppNotice(
      tone: AppTone.caution,
      icon: Icons.event_busy_outlined,
      title:
          'Your ${budget.name} budget ended on '
          '${DateFormat('d MMM').format(budget.endDate)}',
      message: 'Start the next one, or add this to a day before it ended.',
      action: Wrap(
        spacing: AppSpacing.sm,
        children: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(StartNextPeriod.location(budget.id)),
            child: const Text('Start next budget'),
          ),
          TextButton(
            onPressed: () => _pickOtherDay(budget),
            child: Text('Add to ${budget.name}'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasInput,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: _SwipeGuard(
        active: _hasInput,
        onSwipeDown: () => Navigator.of(context).maybePop(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHandle(),
            Flexible(child: _buildContent(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
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
        final failed = state.quickAddLoad == QuickAddLoad.failed;
        final noBudget = loaded && budget == null;
        final currency = budget?.currency;
        final notice = loaded && budget != null ? _periodNotice(budget) : null;
        final notStarted = budget != null && _startsLater(budget);

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
                    if (notice != null) ...[
                      notice,
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    _AmountDisplay(
                      entry: _entry,
                      currency: currency,
                      hasError: _amountError != null,
                    ),
                    if (_amountError != null)
                      Center(child: _CenteredError(message: _amountError!)),
                    const SizedBox(height: AppSpacing.md),
                    if (failed)
                      AppNotice(
                        tone: AppTone.caution,
                        icon: Icons.error_outline_rounded,
                        title: "Couldn't load",
                        message:
                            'Your budget and categories are still on this '
                            'device. Try again.',
                        action: TextButton(
                          onPressed: () => context.read<ExpenseBloc>().add(
                            ExpenseLoadQuickAdd(now: _now),
                          ),
                          child: const Text('Try again'),
                        ),
                      )
                    else if (noBudget)
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
                      canAdd: budget != null && !notStarted,
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

/// The sheet's drag handle, drawn here rather than by the route so a swipe
/// on it goes through [_SwipeGuard] too. Same size and colour as the
/// theme's.
class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = theme.bottomSheetTheme.dragHandleSize ?? const Size(32, 4);
    return Semantics(
      label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      container: true,
      button: true,
      onTap: () => Navigator.of(context).maybePop(),
      child: SizedBox(
        height: kMinInteractiveDimension,
        child: Center(
          child: Container(
            width: size.width,
            height: size.height,
            decoration: BoxDecoration(
              color:
                  theme.bottomSheetTheme.dragHandleColor ??
                  theme.colorScheme.onSurfaceVariant,
              borderRadius: BorderRadius.circular(size.height / 2),
            ),
          ),
        ),
      ),
    );
  }
}

/// While [active], takes vertical drags from the sheet, whose own drag
/// closes it without asking; a swipe down calls [onSwipeDown] instead.
/// Otherwise the sheet drags as usual.
class _SwipeGuard extends StatelessWidget {
  final bool active;
  final VoidCallback onSwipeDown;
  final Widget child;

  const _SwipeGuard({
    required this.active,
    required this.onSwipeDown,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Always present, so turning it on never rebuilds the sheet.
    return GestureDetector(
      onVerticalDragUpdate: active ? (_) {} : null,
      onVerticalDragEnd: active
          ? (details) {
              if ((details.primaryVelocity ?? 0) > 300) onSwipeDown();
            }
          : null,
      child: child,
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
