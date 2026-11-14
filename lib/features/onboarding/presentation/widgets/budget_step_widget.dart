import 'package:flutter/material.dart';
import '../../../../core/widgets/app_money.dart';
import 'package:intl/intl.dart';

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

  /// The amount is a day's (blueprint): the field is the daily target and
  /// the sum under it gives the budget amount over [days].
  final bool byDay;
  final int? days;

  /// The budget's currency, for the sum; the symbol alone when null.
  final String? currencyCode;

  /// "A day" / "In total"; no switch when null.
  final ValueChanged<bool>? onModeChanged;

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
    this.byDay = false,
    this.days,
    this.currencyCode,
    this.onModeChanged,
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

    final byDay = widget.byDay;
    final days = widget.days;
    final daily = double.tryParse(_controller.text.trim());
    String money(double v) => widget.currencyCode != null
        ? AppMoney.format(v, currency: widget.currencyCode)
        : '${widget.currencySymbol}${NumberFormat('#,##0.###').format(v)}';
    final sum = byDay && days != null && daily != null && daily > 0 && _isValid
        ? '${money(daily)} a day × $days ${days == 1 ? 'day' : 'days'} = '
              '${money(daily * days)}'
        : null;
    return OnboardingStepLayout(
      title: byDay
          ? 'How much do you want to spend each day?'
          : 'What is your budget amount?',
      subtitle: byDay
          ? 'Your daily target. The budget amount follows from the dates '
                'you choose next.'
          : 'The total you want to spend between the start and end dates '
                'you choose next.',
      onBack: widget.onBack,
      footer: OnboardingContinueButton(
        buttonKey: const Key('budgetStepContinueButton'),
        onPressed: _isValid ? widget.onContinue : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.onModeChanged != null) ...[
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: true, label: Text('A day')),
                  ButtonSegment(value: false, label: Text('In total')),
                ],
                selected: {byDay},
                onSelectionChanged: (v) => widget.onModeChanged!(v.single),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AppAmountField(
            key: const Key('monthlyBudgetTextField'),
            hero: true,
            controller: _controller,
            focusNode: _focus,
            currency: null,
            symbol: widget.currencySymbol,
            decimals: widget.maxDecimals,
            label: byDay ? 'Daily target' : 'Budget amount',
            hintText: byDay ? '1000' : '30000',
            errorText: widget.errorMessage,
            onChanged: (val) {
              widget.onChanged(val);
              setState(() {});
            },
            onSubmitted: (_) {
              if (_isValid) widget.onContinue();
            },
          ),
          if (sum != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              key: const Key('onboardingByDaySum'),
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sum,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'That becomes the budget amount.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
