import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_amount_field.dart';
import 'onboarding_step_layout.dart';
import '../../../../core/currency/money_input.dart';

class BudgetStepWidget extends StatefulWidget {
  final String initialValue;
  final String currencySymbol;

  /// Decimals the amount may have, from [MoneyInput.maxDecimals].
  final int maxDecimals;
  final String? errorMessage;
  final ValueChanged<String> onChanged;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  /// This step is the page on screen and has stopped sliding in; its
  /// field takes focus then (UX-111). True on its own, outside a pager.
  final bool active;

  const BudgetStepWidget({
    super.key,
    this.active = true,
    required this.initialValue,
    required this.currencySymbol,
    this.maxDecimals = 2,
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

  /// The field takes focus when this step becomes [BudgetStepWidget.active].
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.active) _focusSoon();
  }

  @override
  void didUpdateWidget(covariant BudgetStepWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _focusSoon();
  }

  void _focusSoon() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && widget.active) _focus.requestFocus();
  });

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool get _isValid =>
      widget.errorMessage == null && _controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          AppAmountField(
            key: const Key('monthlyBudgetTextField'),
            hero: true,
            controller: _controller,
            focusNode: _focus,
            currency: null,
            symbol: widget.currencySymbol,
            decimals: widget.maxDecimals,
            label: 'Budget amount',
            hintText: '30000',
            errorText: widget.errorMessage,
            onChanged: (val) {
              widget.onChanged(val);
              setState(() {});
            },
            onSubmitted: (_) {
              if (_isValid) widget.onContinue();
            },
          ),
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
