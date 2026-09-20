import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';
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
    final isSubmitting = state.status == OnboardingStatus.loading;
    final days = state.endDate.difference(state.startDate).inDays + 1;
    final amount = state.parsedBudget ?? 0;
    final perDay = days > 0 ? amount / days : 0.0;
    final dateFmt = DateFormat('EEE, d MMM yyyy');
    final code = state.selectedCurrency.code;

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
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.mlg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconTile(
                      icon: Icons.account_balance_wallet_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.smd),
                    Expanded(
                      child: Text(
                        state.budgetNameInput.trim().isEmpty
                            ? 'Your budget'
                            : state.budgetNameInput.trim(),
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyFormatter.format(amount, code: code),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Text(
                  '${state.selectedCurrency.name} ($code)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Divider(height: AppSpacing.lg),
                _Row(label: 'Starts', value: dateFmt.format(state.startDate)),
                _Row(label: 'Ends', value: dateFmt.format(state.endDate)),
                _Row(
                  label: 'Length',
                  value:
                      '$days ${days == 1 ? 'day' : 'days'} · '
                      '${formatShortDateRange(state.startDate, state.endDate)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          StatusCard(
            color: theme.colorScheme.primary,
            icon: Icons.today_rounded,
            title:
                "Today's Safe Spending starts at about "
                '${CurrencyFormatter.format(perDay, code: code, decimalDigits: 0)}',
            message:
                'That is your amount spread evenly over $days '
                '${days == 1 ? 'day' : 'days'}. It updates every day based '
                'on what you have spent.',
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
