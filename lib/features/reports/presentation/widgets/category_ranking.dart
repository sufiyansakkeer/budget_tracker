import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_track.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../../../expenses/domain/entities/expense_entity.dart';
import '../../../expenses/presentation/widgets/category_visuals.dart';
import '../../../expenses/presentation/widgets/transaction_row.dart';
import '../../domain/entities/category_analytics.dart';
import '../../../../core/dates/date_range_format.dart';

/// Where the money went: every category ranked by amount, each with a bar
/// in its own colour, scaled to the largest. Tapping one lists those
/// expenses, and tapping an expense there opens it.
///
/// The five largest show first; the rest are one tap away, so a long tail
/// never pushes the rest of the report down.
class CategoryRanking extends StatefulWidget {
  final List<CategoryAnalytics> analytics;
  final List<ExpenseCategory> categories;

  /// The report's expenses, to list a category's own.
  final List<ExpenseEntity> expenses;
  final String currency;

  /// Opens one expense from a category's list, after the list closes
  /// (UX-090): its details can edit or delete it, and the list would be
  /// stale behind them.
  final ValueChanged<ExpenseEntity> onOpenExpense;

  const CategoryRanking({
    super.key,
    required this.analytics,
    required this.categories,
    required this.expenses,
    required this.currency,
    required this.onOpenExpense,
  });

  static const int collapsed = 5;

  @override
  State<CategoryRanking> createState() => _CategoryRankingState();
}

class _CategoryRankingState extends State<CategoryRanking> {
  bool _all = false;

  ExpenseCategory? _category(String id) {
    for (final c in widget.categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _open(CategoryAnalytics a) async {
    final own = [
      for (final e in widget.expenses)
        if (e.categoryId == a.categoryId) e,
    ]..sort((x, y) => y.time.compareTo(x.time));
    final chosen = await AppBottomSheet.show<ExpenseEntity>(
      context: context,
      builder: (_) => _CategoryExpensesSheet(
        analytics: a,
        category: _category(a.categoryId),
        expenses: own,
        currency: widget.currency,
      ),
    );
    if (chosen != null && mounted) widget.onOpenExpense(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final ranked = widget.analytics;
    final shown = _all || ranked.length <= CategoryRanking.collapsed
        ? ranked
        : ranked.take(CategoryRanking.collapsed).toList();
    final largest = ranked.isEmpty ? 0.0 : ranked.first.totalAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final a in shown)
          _CategoryBar(
            key: ValueKey('rank_${a.categoryId}'),
            analytics: a,
            category: _category(a.categoryId),
            // Bars are relative to the largest, so the ranking is easy to
            // read even when one category dominates. They have no track:
            // on one a 37% category drawn full width read as a full
            // budget (UX-088).
            fraction: largest <= 0 ? 0 : a.totalAmount / largest,
            currency: widget.currency,
            onTap: () => _open(a),
          ),
        if (ranked.length > CategoryRanking.collapsed)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => setState(() => _all = !_all),
              child: Text(
                _all
                    ? 'Show the top ${CategoryRanking.collapsed}'
                    : 'Show all ${ranked.length} categories',
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final CategoryAnalytics analytics;
  final ExpenseCategory? category;
  final double fraction;
  final String currency;
  final VoidCallback onTap;

  const _CategoryBar({
    super.key,
    required this.analytics,
    required this.category,
    required this.fraction,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = CategoryVisuals.adaptiveColor(context, analytics.colorHex);
    final percent = analytics.percentageOfTotal.round();
    final count = analytics.transactionCount;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final amount = AppMoney.format(analytics.totalAmount, currency: currency);

    return Semantics(
      button: true,
      label: CurrencyFormatter.forSpeech(
        '${analytics.categoryName}, $amount, $percent% of spending, '
        '$count ${count == 1 ? 'expense' : 'expenses'}',
      ),
      hint: 'Shows these expenses',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusSm,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              IconTile(
                icon: CategoryVisuals.iconFor(category?.icon ?? ''),
                color: color,
                size: AppSizes.avatarSm,
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            analytics.categoryName,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.4,
                          ),
                          child: AppMoney(
                            amount: analytics.totalAmount,
                            currency: currency,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AppTrack(
                      value: fraction,
                      color: color,
                      trackColor: Colors.transparent,
                      height: 6,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '$percent% · $count ${count == 1 ? 'expense' : 'expenses'}',
                      style: muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One category's expenses in the report's period, newest first.
class _CategoryExpensesSheet extends StatelessWidget {
  final CategoryAnalytics analytics;
  final ExpenseCategory? category;
  final List<ExpenseEntity> expenses;
  final String currency;

  const _CategoryExpensesSheet({
    required this.analytics,
    required this.category,
    required this.expenses,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final color = CategoryVisuals.adaptiveColor(context, analytics.colorHex);
    final icon = CategoryVisuals.iconFor(category?.icon ?? '');
    final count = expenses.length;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSheetHeader(
            title: analytics.categoryName,
            subtitle:
                '${AppMoney.format(analytics.totalAmount, currency: currency)}'
                ' · $count ${count == 1 ? 'expense' : 'expenses'}',
          ),
          // Built lazily: a busy category over a year has hundreds of
          // rows (UX-090). Dividers as AppGroupedList draws them.
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              itemCount: expenses.length,
              separatorBuilder: (context, _) => Divider(
                indent: AppSizes.avatarSm + AppSpacing.smd,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              itemBuilder: (context, i) => _ExpenseRow(
                key: ValueKey('rankExpense_${expenses[i].id}'),
                expense: expenses[i],
                icon: icon,
                color: color,
                categoryName: analytics.categoryName,
                currency: currency,
                onTap: () => Navigator.of(context).pop(expenses[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  final ExpenseEntity expense;
  final IconData icon;
  final Color color;
  final String categoryName;
  final String currency;
  final VoidCallback onTap;

  const _ExpenseRow({
    super.key,
    required this.onTap,
    required this.expense,
    required this.icon,
    required this.color,
    required this.categoryName,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final note = expense.note?.trim();
    final title = note == null || note.isEmpty ? categoryName : note;
    final day = AppDates.weekday(expense.date);
    final time = AppDates.time(context, expense.time);
    return TransactionRow(
      icon: icon,
      color: color,
      title: title,
      detail: day,
      when: time,
      amount: expense.amount,
      currency: currency,
      hasReceipt: expense.receiptImagePath != null,
      onTap: onTap,
      semanticLabel:
          '$title, ${AppMoney.format(expense.amount, currency: currency)}, '
          '$day, $time',
    );
  }
}
