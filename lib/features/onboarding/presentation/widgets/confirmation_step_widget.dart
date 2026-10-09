import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_metric.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/app_header.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isSubmitting = state.status == OnboardingStatus.loading;
    final amount = state.parsedBudget ?? 0;
    // The dashboard's own figure for the first day; null while the dates
    // are invalid.
    final firstDay = state.firstDaySafeToSpend;
    final days = firstDay?.totalDays;
    final dateFmt = DateFormat('EEE, d MMM yyyy');
    final code = state.selectedCurrency.code;
    final name = state.budgetNameInput.trim();
    final amountText = AppMoney.format(amount, currency: code);

    final Widget hero;
    if (firstDay != null && days != null) {
      // Floored like every "safe" amount, so the preview never promises
      // more than the dashboard will show.
      final daily = AppMoney.format(
        firstDay.dailySafeToSpend,
        currency: code,
        floored: true,
      );
      hero = Semantics(
        container: true,
        label:
            "Today's Safe Spending starts at $daily. $amountText spread "
            'evenly over $days ${days == 1 ? 'day' : 'days'}.',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Today's Safe Spending starts at",
                style: theme.textTheme.titleSmall?.copyWith(color: muted),
              ),
              AppMoney(
                amount: firstDay.dailySafeToSpend,
                currency: code,
                role: MoneyRole.hero,
                floored: true,
                split: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$amountText spread evenly over $days '
                '${days == 1 ? 'day' : 'days'}. It updates every day with '
                'what you spend.',
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
