import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_metric.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/dates/calendar_dates.dart';
import '../../../../core/dates/date_range_format.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_status.dart';
import '../bloc/onboarding_state.dart';
import 'onboarding_step_layout.dart';

class ConfirmationStepWidget extends StatelessWidget {
  final OnboardingState state;
  final VoidCallback onCreateBudget;
  final VoidCallback onBack;

  const ConfirmationStepWidget({
    super.key,
    required this.state,
    required this.onCreateBudget,
    required this.onBack,
  });

  /// "Now" for the preview's day; replaced in tests.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isSubmitting = state.status == OnboardingStatus.loading;
    final amount = state.parsedBudget ?? 0;
    // The dashboard's own figure for the first day it shows the budget;
    // null while the dates are invalid.
    final today = clock().dateOnly;
    final preview = state.safeToSpendPreview(today);
    final days = preview?.totalDays;
    final dateFmt = DateFormat('EEE, d MMM yyyy');
    final code = state.selectedCurrency.code;
    final name = state.budgetNameInput.trim();
    final amountText = AppMoney.format(amount, currency: code);

    final Widget hero;
    // An ended budget has no daily figure: it shows its amount instead.
    if (preview != null &&
        days != null &&
        preview.status != SafeToSpendStatus.periodEnded) {
      // Floored like every "safe" amount, so the preview never promises
      // more than the dashboard will show.
      final daily = AppMoney.format(
        preview.dailySafeToSpend,
        currency: code,
        floored: true,
      );
      // The preview is the start day's figure when the start is to come.
      final notStarted = state.startDate.dateOnly.isAfter(today);
      final label = notStarted
          ? "From ${DateFormat('d MMM').format(state.startDate)}, "
                "Today's Safe Spending starts at"
          : "Today's Safe Spending";
      final left = preview.remainingDays;
      final spread = notStarted || left == days
          ? '$amountText spread evenly over $days '
                '${days == 1 ? 'day' : 'days'}'
          : '$amountText spread evenly over the $left '
                '${left == 1 ? 'day' : 'days'} left';
      hero = Semantics(
        container: true,
        label: notStarted
            ? '$label $daily. $spread.'
            : '$label: $daily. $spread.',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(color: muted),
              ),
              AppMoney(
                amount: preview.dailySafeToSpend,
                currency: code,
                role: MoneyRole.hero,
                floored: true,
                split: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$spread. It updates every day with what you spend.',
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ],
          ),
        ),
      );
    } else {
      hero = AppMetric(
        label: 'Budget amount',
        value: AppMoney(
          amount: amount,
          currency: code,
          role: MoneyRole.display,
        ),
      );
    }

    return OnboardingStepLayout(
      title: 'Ready to create your budget?',
      subtitle:
          'It becomes your active budget. You can add more budgets any '
          'time.',
      onBack: isSubmitting ? null : onBack,
      footer: OnboardingContinueButton(
        buttonKey: const Key('createBudgetButton'),
        label: 'Create budget',
        icon: Icons.check_rounded,
        isLoading: isSubmitting,
        onPressed: onCreateBudget,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSurface(
            padding: const EdgeInsets.all(AppSpacing.mlg),
            child: hero,
          ),
          const SizedBox(height: AppSpacing.lg),
          _Facts(
            facts: [
              ('Budget', name.isEmpty ? 'Your budget' : name),
              ('Amount', '$amountText · $code'),
              ('Starts', dateFmt.format(state.startDate)),
              ('Ends', dateFmt.format(state.endDate)),
              (
                'Length',
                days == null
                    ? formatShortDateRange(state.startDate, state.endDate)
                    : '$days ${days == 1 ? 'day' : 'days'}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The draft's facts as labelled values, two to a row.
class _Facts extends StatelessWidget {
  final List<(String, String)> facts;

  const _Facts({required this.facts});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.md;
        // Floored so rounding never pushes an item onto a new run.
        final width = ((constraints.maxWidth - gap) / 2).floorToDouble();
        return Wrap(
          spacing: gap,
          runSpacing: AppSpacing.md,
          children: [
            for (final (label, value) in facts)
              SizedBox(
                width: width,
                child: AppMetric(
                  label: label,
                  value: Text(value, style: style),
                ),
              ),
          ],
        );
      },
    );
  }
}
