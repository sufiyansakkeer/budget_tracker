import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../expenses/presentation/widgets/form_field_error.dart';
import 'onboarding_step_layout.dart';

class BudgetStepWidget extends StatefulWidget {
  final String initialValue;
  final String currencySymbol;
  final String? errorMessage;
  final ValueChanged<String> onChanged;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const BudgetStepWidget({
    super.key,
    required this.initialValue,
    required this.currencySymbol,
    this.errorMessage,
    required this.onChanged,
    required this.onContinue,
    required this.onBack,
  });

  @override
  State<BudgetStepWidget> createState() => _BudgetStepWidgetState();
}

class _BudgetStepWidgetState extends State<BudgetStepWidget> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isValid =>
      widget.errorMessage == null && _controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = widget.errorMessage != null;

    return OnboardingStepLayout(
      title: 'What is your budget amount?',
      subtitle:
          'The total you want to spend between the start and end dates '
          'you choose next.',
      onBack: widget.onBack,
      footer: OnboardingContinueButton(
        buttonKey: const Key('budgetStepContinueButton'),
        onPressed: _isValid ? widget.onContinue : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: AppSpacing.borderRadiusMd,
              border: Border.all(
                color: hasError
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: AppSizes.avatarMd,
                  height: AppSizes.avatarMd,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: AppSpacing.borderRadiusSmd,
                  ),
                  child: Text(
                    widget.currencySymbol,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: TextField(
                    key: const Key('monthlyBudgetTextField'),
                    controller: _controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    autofocus: true,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    decoration: InputDecoration(
                      hintText: '30,000',
                      hintStyle: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.25,
                        ),
                      ),
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                    ),
                    onChanged: (val) {
                      widget.onChanged(val);
                      setState(() {});
                    },
                    onSubmitted: (_) {
                      if (_isValid) widget.onContinue();
                    },
                  ),
                ),
              ],
            ),
          ),
          if (hasError) FormFieldError(message: widget.errorMessage!),
          const SizedBox(height: AppSpacing.md),
          Text(
            'You can change the amount any time from the budget screen.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
