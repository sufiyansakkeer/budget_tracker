import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../bloc/onboarding_state.dart';

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

  String _formatAmount(double? amount) {
    if (amount == null) return '0';
    final isInteger = amount % 1 == 0;
    if (isInteger) {
      return amount.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    }
    return amount.toStringAsFixed(2);
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSubmitting = state.status == OnboardingStatus.loading;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: isSubmitting ? null : onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Confirm Your Budget',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Review your budget configuration before creating it.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Budget Name',
                    value: state.budgetNameInput.trim().isEmpty
                        ? 'Personal'
                        : state.budgetNameInput.trim(),
                  ),
                  const Divider(height: AppSpacing.xl),
                  _SummaryRow(
                    label: 'Budget Amount',
                    value:
                        '${state.selectedCurrency.symbol}${_formatAmount(state.parsedBudget)}',
                    isPrimary: true,
                  ),
                  const Divider(height: AppSpacing.xl),
                  _SummaryRow(
                    label: 'Currency',
                    value:
                        '${state.selectedCurrency.code} (${state.selectedCurrency.symbol})',
                  ),
                  const Divider(height: AppSpacing.xl),
                  _SummaryRow(
                    label: 'Start Date',
                    value: _formatDate(state.startDate),
                  ),
                  const Divider(height: AppSpacing.xl),
                  _SummaryRow(
                    label: 'End Date',
                    value: _formatDate(state.endDate),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              key: const Key('createBudgetButton'),
              onPressed: isSubmitting ? null : onCreateBudget,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Create Budget',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isPrimary;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.textTheme.titleMedium?.color?.withValues(alpha: 0.7),
          ),
        ),
        Text(
          value,
          style: isPrimary
              ? theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                )
              : theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
        ),
      ],
    );
  }
}
