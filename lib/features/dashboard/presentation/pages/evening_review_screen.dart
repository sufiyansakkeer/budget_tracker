import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/navigation/push_unique.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/app_list.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_page_body.dart';
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../budget/domain/entities/budget_error.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import '../../../budget/domain/usecases/manage_budget_usecase.dart';
import '../../../expenses/presentation/quick_add/quick_add_sheet.dart';
import '../../domain/entities/recent_expense_entity.dart';
import '../../domain/usecases/get_recent_expenses_usecase.dart';
import '../../domain/usecases/get_safe_to_spend_usecase.dart';
import '../widgets/recent_expense_tile.dart';
import '../widgets/safe_to_spend_copy.dart';
import '../widgets/target_ring.dart';

/// Today's figures and today's expenses (newest first), for the review.
typedef EveningReview = (SafeToSpendEntity today, List<RecentExpenseEntity>);

/// The evening review (blueprint), opened from the evening summary: the
/// day's ring, tomorrow's target and how much it moved, a prompt for
/// anything forgotten, then the day's expenses.
class EveningReviewScreen extends StatefulWidget {
  /// The active budget's day; null when none runs today.
  final Future<EveningReview?> Function() load;

  /// "Add an expense from today": quick add in the app.
  final Future<void> Function(BuildContext context) onAddForgotten;

  const EveningReviewScreen({
    super.key,
    this.load = readActiveToday,
    this.onAddForgotten = QuickAddSheet.show,
  });

  /// The active budget's figures and expenses today; null when it isn't
  /// running or can't be read.
  static Future<EveningReview?> readActiveToday() async {
    try {
      final id = await getIt<ManageBudgetUseCase>().activeBudgetId();
      if (id == null) return null;
      final result = await getIt<GetSafeToSpendUseCase>()(budgetId: id);
      if (result case BudgetSuccess(:final data) when data.isRunning) {
        final day = data.today;
        final recent = await getIt<GetRecentExpensesUseCase>()(
          budgetId: id,
          referenceDate: day,
          limit: 50,
        );
        return (
          data,
          [
            for (final e in recent)
              if (DateUtils.isSameDay(e.date, day)) e,
          ],
        );
      }
    } catch (e) {
      debugPrint('[error] Reading today for the evening review: $e');
    }
    return null;
  }

  @override
  State<EveningReviewScreen> createState() => _EveningReviewScreenState();
}

class _EveningReviewScreenState extends State<EveningReviewScreen> {
  late Future<EveningReview?> _review = widget.load();

  void _done() => context.canPop() ? context.pop() : context.go('/app/home');

  Future<void> _addForgotten() async {
    await widget.onAddForgotten(context);
    if (!mounted) return;
    setState(() {
      _review = widget.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EveningReview?>(
      future: _review,
      builder: (context, snapshot) {
        final review = snapshot.data;
        final loading = snapshot.connectionState != ConnectionState.done;
        final Widget child;
        if (loading) {
          child = const FormSkeleton(key: ValueKey('loading'), rows: 3);
        } else if (review == null) {
          child = EmptyState(
            key: const ValueKey('none'),
            icon: Icons.nights_stay_outlined,
            title: 'No budget is running today',
            message: 'The review follows the active budget while it runs.',
            actionLabel: 'Done',
            onAction: _done,
          );
        } else {
          child = _Review(
            key: const ValueKey('review'),
            review: review,
            onAddForgotten: _addForgotten,
          );
        }
        return Scaffold(
          appBar: AppBar(),
          body: AppStateSwitcher(child: child),
          bottomNavigationBar: review == null
              ? null
              : SafeArea(
                  minimum: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _done,
                          child: const Text('Not now'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.smd),
                      Expanded(
                        child: FilledButton(
                          onPressed: _done,
                          child: const Text('Done for today'),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _Review extends StatelessWidget {
  final EveningReview review;
  final VoidCallback onAddForgotten;

  const _Review({
    super.key,
    required this.review,
    required this.onAddForgotten,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (e, expenses) = review;
    final over = e.overToday > 0;
    final caution = context.tone(AppTone.caution).accent;
    final tomorrow = e.tomorrowIfNoMoreSpending ?? e.dailySafeToSpend;
    // Between the two figures as shown (both floored), so they add up.
    double shown(double v) =>
        CurrencyFormatter.floorForDisplay(v, code: e.currency).amount;
    final change = shown(tomorrow) - shown(e.dailySafeToSpend);
    final changeText = change.abs() < 0.005
        ? 'No change'
        : '${change > 0 ? '+' : '−'}${AppMoney.format(change.abs(), currency: e.currency)}';
    final target = SafeToSpendCopy.safeAmount(e.dailySafeToSpend, e.currency);
    final spoken =
        '${over ? 'Over by ${SafeToSpendCopy.amount(e.overToday, e.currency)}' : '${SafeToSpendCopy.safeAmount(e.remainingToday, e.currency)} left'} '
        'of $target today.';

    Widget card(String label, String value, {bool lead = false, Color? ink}) =>
        DecoratedBox(
          decoration: BoxDecoration(
            color: lead ? scheme.primaryContainer : scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.smd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: lead
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: ink ?? (lead ? scheme.onPrimaryContainer : null),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.xs),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    return AppPageBody(
      builder: (context, padding) => ListView(
        padding: padding,
        children: [
          Text(
            '${DateFormat('EEEE d MMMM').format(e.today)} · '
            '${DateFormat.jm().format(DateTime.now())}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          Semantics(
            header: true,
            child: Text(
              'Today, reviewed',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TargetRing(
              spent: e.todayDiscretionary,
              target: e.dailySafeToSpend,
              segments: [for (final x in expenses.reversed) x.amount],
              diameter: 170,
              stroke: 15,
              semanticsLabel: CurrencyFormatter.forSpeech(spoken),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    over ? 'Over' : 'Left',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: over ? caution : scheme.onSurfaceVariant,
                    ),
                  ),
                  AppMoney(
                    amount: over ? e.overToday : e.remainingToday,
                    currency: e.currency,
                    role: MoneyRole.display,
                    floored: !over,
                    split: true,
                    color: over ? caution : null,
                  ),
                  Text(
                    'of $target',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: card(
                    "Tomorrow's target",
                    SafeToSpendCopy.safeAmount(tomorrow, e.currency),
                    lead: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: card(
                    'Change',
                    changeText,
                    ink: change < -0.005
                        ? caution
                        : change > 0.005
                        ? context.tone(AppTone.positive).accent
                        : null,
                  ),
                ),
              ],
            ),
          ),
          heading('Anything you forgot?'),
          AppListRow(
            leading: Icon(Icons.add_rounded, color: scheme.onSurfaceVariant),
            title: 'Add an expense from today',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onAddForgotten,
          ),
          heading('Today'),
          if (expenses.isEmpty)
            Text(
              'Nothing spent today.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            AppGroupedList(
              dividerIndent: AppSizes.avatarSm + AppSpacing.md,
              children: [
                for (final x in expenses)
                  RecentExpenseTile(
                    key: ValueKey('review_${x.id}'),
                    expense: x,
                    currency: e.currency,
                    today: e.today,
                    onTap: () => context.pushUnique('/app/expenses/${x.id}'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
