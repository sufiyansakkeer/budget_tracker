import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/events/refresh_bus.dart';
import '../../../../core/navigation/push_unique.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../bills/domain/entities/bill_entity.dart';
import '../../../bills/domain/entities/bill_failure.dart';
import '../../../bills/domain/usecases/get_bills_usecase.dart';
import '../../../budget/domain/usecases/manage_budget_usecase.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../../../expenses/domain/entities/expense_failure.dart';
import '../../../expenses/domain/usecases/get_categories_usecase.dart';
import '../../../pay_later/domain/entities/pay_later_failure.dart';
import '../../../pay_later/domain/entities/pay_later_overview.dart';
import '../../../pay_later/domain/usecases/get_pay_later_overview_usecase.dart';

/// The live line under each More tile. Anything that could not be read
/// keeps its plain description ([fallback]).
/// Blueprint .tg2 gap.
const double _gap = 10;

class MoreTileValues {
  final String bills;
  final String payLater;
  final String categories;
  final String budgets;

  const MoreTileValues({
    required this.bills,
    required this.payLater,
    required this.categories,
    required this.budgets,
  });

  static const fallback = MoreTileValues(
    bills: 'Due dates and reminders',
    payLater: 'Buy now, pay later',
    categories: 'Add your own or restyle',
    budgets: 'Create, switch and archive',
  );

  /// Values from what could be read (null = not read), on [today].
  factory MoreTileValues.from({
    required DateTime today,
    List<BillEntity>? bills,
    PayLaterOverview? payLater,
    int? categoryCount,
    List<BudgetEntity>? budgets,
  }) {
    final day = DateTime(today.year, today.month, today.day);
    DateTime dateOf(DateTime d) => DateTime(d.year, d.month, d.day);
    return MoreTileValues(
      bills: bills == null ? fallback.bills : _bills(bills, day, dateOf),
      payLater: payLater == null ? fallback.payLater : _payLater(payLater),
      categories: categoryCount == null
          ? fallback.categories
          : '$categoryCount in use',
      budgets: budgets == null ? fallback.budgets : _budgets(budgets, day),
    );
  }

  static String _bills(
    List<BillEntity> bills,
    DateTime today,
    DateTime Function(DateTime) dateOf,
  ) {
    final weekEnd = DateTime(today.year, today.month, today.day + 7);
    var overdue = 0;
    var soon = 0;
    for (final b in bills.where((b) => !b.isPaid)) {
      final due = dateOf(b.dueDate);
      if (due.isBefore(today)) {
        overdue++;
      } else if (!due.isAfter(weekEnd)) {
        soon++;
      }
    }
    final parts = [
      if (overdue > 0) '$overdue overdue',
      if (soon > 0) '$soon due soon',
    ];
    return parts.isEmpty ? 'Nothing due soon' : parts.join(' · ');
  }

  static String _payLater(PayLaterOverview overview) {
    final owing = [
      for (final t in overview.totals)
        if (t.owed > 0) t,
    ];
    if (owing.isEmpty) return 'Nothing owed';
    final first = AppMoney.format(
      owing.first.owed,
      currency: owing.first.currency,
    );
    final more = owing.length > 1 ? ' + ${owing.length - 1} more' : '';
    final overdue = owing.where((t) => t.overdue > 0).length;
    final late = overdue > 0 ? ' · $overdue overdue' : '';
    return '$first owed$more$late';
  }

  static String _budgets(List<BudgetEntity> budgets, DateTime today) {
    final open = budgets.where((b) => !b.isArchived);
    final running = open.where((b) => b.isActiveOn(today)).length;
    final later = open.where((b) => b.startDate.isAfter(today)).length;
    final parts = [
      if (running > 0) '$running running',
      if (later > 0) '$later later',
    ];
    return parts.isEmpty ? 'None running' : parts.join(' · ');
  }

  /// Reads everything the tiles describe; a part that fails keeps its
  /// fallback.
  static Future<MoreTileValues> read() async {
    T? registered<T extends Object>() =>
        getIt.isRegistered<T>() ? getIt<T>() : null;
    Future<R?> attempt<R>(Future<R?> Function() read) async {
      try {
        return await read();
      } catch (e) {
        debugPrint('[error] Reading a More tile: $e');
        return null;
      }
    }

    final bills = await attempt(() async {
      final result = await registered<GetBillsUseCase>()?.call();
      return result is BillSuccess<List<BillEntity>> ? result.data : null;
    });
    final payLater = await attempt(() async {
      final result = await registered<GetPayLaterOverviewUseCase>()?.call();
      return result is PayLaterSuccess<PayLaterOverview> ? result.data : null;
    });
    final categories = await attempt(() async {
      final result = await registered<GetCategoriesUseCase>()?.call();
      return result is ExpenseSuccess<List<ExpenseCategory>>
          ? result.data.length
          : null;
    });
    final budgets = await attempt(
      () async => registered<ManageBudgetUseCase>()?.getAll(),
    );
    return MoreTileValues.from(
      today: DateTime.now(),
      bills: bills,
      payLater: payLater,
      categoryCount: categories,
      budgets: budgets,
    );
  }
}

/// The top of More: every feature beyond the daily view as a tile with a
/// live line ("1 overdue", "₹3,460 owed"), one tap away. "Your data" scrolls
/// to the data settings below ([onData]).
class MoreTiles extends StatefulWidget {
  /// Reads the live lines; [MoreTileValues.read] in the app.
  final Future<MoreTileValues> Function() load;
  final VoidCallback onData;

  const MoreTiles({
    super.key,
    this.load = MoreTileValues.read,
    required this.onData,
  });

  @override
  State<MoreTiles> createState() => _MoreTilesState();
}

class _MoreTilesState extends State<MoreTiles> {
  MoreTileValues _values = MoreTileValues.fallback;
  final List<StreamSubscription<void>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _load();
    for (final bus in [
      RefreshBuses.bills,
      RefreshBuses.payLater,
      RefreshBuses.budgets,
      RefreshBuses.expenses,
      RefreshBuses.day,
    ]) {
      _subscriptions.add(bus.changes.listen((_) => _load()));
    }
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final values = await widget.load();
    if (mounted) setState(() => _values = values);
  }

  @override
  Widget build(BuildContext context) {
    final v = _values;
    final tiles = [
      (
        'more_bills',
        Icons.receipt_long_outlined,
        'Bills',
        v.bills,
        '/app/bills',
      ),
      (
        'more_payLater',
        Icons.credit_card_outlined,
        'Pay later',
        v.payLater,
        '/app/pay-later',
      ),
      (
        'more_categories',
        Icons.category_outlined,
        'Categories',
        v.categories,
        '/app/categories',
      ),
      (
        'more_converter',
        Icons.currency_exchange_rounded,
        'Currency converter',
        'Between any two currencies',
        '/app/settings/converter',
      ),
      (
        'more_budgets',
        Icons.account_balance_wallet_outlined,
        'All budgets',
        v.budgets,
        '/app/budgets/all',
      ),
      (
        'more_data',
        Icons.cloud_outlined,
        'Your data',
        'Export, back up, restore',
        null,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 3 : 2;
        final width = (constraints.maxWidth - _gap * (columns - 1)) / columns;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final (key, icon, title, line, path) in tiles)
              SizedBox(
                width: width,
                child: _Tile(
                  key: Key(key),
                  icon: icon,
                  title: title,
                  line: line,
                  onTap: path == null
                      ? widget.onData
                      : () => context.pushUnique(path),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String line;
  final VoidCallback onTap;

  const _Tile({
    super.key,
    required this.icon,
    required this.title,
    required this.line,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    // Blueprint .tl2: card tone, radius 18, lifted in light and outlined
    // in dark; the icon at the top, the name and its live line at the foot.
    final radius = BorderRadius.circular(18);
    return Semantics(
      button: true,
      label: '$title, $line',
      excludeSemantics: true,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: dark ? null : AppCard.lift,
        ),
        child: Material(
          color: theme.cardTheme.color,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: dark
                ? BorderSide(color: theme.colorScheme.outlineVariant)
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 112),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconTile(
                      icon: icon,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: AppSizes.avatarSm,
                    ),
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          line,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
