import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/money_input.dart';
import '../../../../core/theme/app_tone.dart';
import '../../../../core/widgets/app_amount_field.dart';
import '../../../../core/widgets/app_list.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../dashboard/presentation/widgets/safe_to_spend_copy.dart';
import '../../domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import '../../domain/entities/safe_to_spend/safe_to_spend_input.dart';
import '../../domain/services/budget_calculation_service.dart';
import '../../domain/services/safe_to_spend_calculator.dart';

/// "Change your daily target" (blueprint): every lever on the target in one
/// sheet. Each change shows its effect a day; nothing is saved until Apply.
///
/// The set-asides (savings goal, kept aside) are edited here, previewed
/// with the engine on [input]; the end date and the budget amount open the
/// budget form ([onOpenForm]).
class ChangeTargetSheet extends StatefulWidget {
  final SafeToSpendInput input;

  /// Saves kept aside and the savings goal (null = not set).
  final Future<void> Function(double? reserved, double? savings) onApply;
  final VoidCallback onOpenForm;

  const ChangeTargetSheet({
    super.key,
    required this.input,
    required this.onApply,
    required this.onOpenForm,
  });

  @override
  State<ChangeTargetSheet> createState() => _ChangeTargetSheetState();
}

class _ChangeTargetSheetState extends State<ChangeTargetSheet> {
  static final _calculator = SafeToSpendCalculator(BudgetCalculationService());

  late final _savings = TextEditingController(
    text: _text(widget.input.savingsTarget),
  );
  late final _kept = TextEditingController(
    text: _text(widget.input.reservedAmount),
  );
  late final SafeToSpendEntity _base = _calculator.calculate(widget.input);
  bool _saving = false;

  static String _text(double? v) =>
      v == null || v == 0 ? '' : MoneyInput.forInput(v);

  static double? _value(TextEditingController c) {
    final v = double.tryParse(c.text.trim());
    return v == null || v <= 0 ? null : v;
  }

  /// The engine on the input with these set-asides.
  SafeToSpendEntity _with({double? reserved, double? savings}) {
    final i = widget.input;
    return _calculator.calculate(
      SafeToSpendInput(
        budgetId: i.budgetId,
        budgetName: i.budgetName,
        currency: i.currency,
        startDate: i.startDate,
        endDate: i.endDate,
        today: i.today,
        budgetAmount: i.budgetAmount,
        periodSpent: i.periodSpent,
        todaySpent: i.todaySpent,
        committedSpentInPeriod: i.committedSpentInPeriod,
        committedSpentToday: i.committedSpentToday,
        commitments: i.commitments,
        currencyExcluded: i.currencyExcluded,
        unlinked: i.unlinked,
        reservedAmount: reserved,
        savingsTarget: savings,
        thresholds: i.thresholds,
      ),
    );
  }

  /// Tomorrow's target, or today's on the last day.
  static double _target(SafeToSpendEntity e) =>
      e.tomorrowIfNoMoreSpending ?? e.dailySafeToSpend;

  @override
  void dispose() {
    _savings.dispose();
    _kept.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    setState(() => _saving = true);
    try {
      await widget.onApply(_value(_kept), _value(_savings));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final i = widget.input;
    final cur = i.currency;
    final kept = _value(_kept);
    final savings = _value(_savings);
    final after = _with(reserved: kept, savings: savings);
    // Each lever's own effect: the other one as it was.
    final savingsEffect =
        _target(_with(reserved: i.reservedAmount, savings: savings)) -
        _target(_base);
    final keptEffect =
        _target(_with(reserved: kept, savings: i.savingsTarget)) -
        _target(_base);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    Widget effect(double perDay) {
      final none = perDay.abs() < 0.005;
      final up = perDay > 0;
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            none
                ? '—'
                : '${up ? '+' : '−'}${AppMoney.format(perDay.abs(), currency: cur)} a day',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: none
                  ? scheme.onSurfaceVariant
                  : up
                  ? context.tone(AppTone.positive).accent
                  : context.tone(AppTone.caution).accent,
            ),
          ),
        ),
      );
    }

    final from = SafeToSpendCopy.safeAmount(_target(_base), cur);
    final to = SafeToSpendCopy.safeAmount(_target(after), cur);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Change your daily target',
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Each change shows its effect a day. Nothing is saved until you '
            'apply it.',
            style: muted,
          ),
          const SizedBox(height: AppSpacing.md),
          AppAmountField(
            controller: _savings,
            currency: cur,
            label: 'Savings goal',
            helperText: 'Money you want left unspent at the end',
            onChanged: (_) => setState(() {}),
          ),
          effect(savingsEffect),
          const SizedBox(height: AppSpacing.sm),
          AppAmountField(
            controller: _kept,
            currency: cur,
            label: 'Kept aside',
            helperText: "Money in this budget you don't want counted",
            onChanged: (_) => setState(() {}),
          ),
          effect(keptEffect),
          const SizedBox(height: AppSpacing.sm),
          AppGroupedList(
            children: [
              AppListRow(
                leading: const Icon(Icons.event_outlined),
                title: 'End date',
                subtitle: 'More days lower the target',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: widget.onOpenForm,
              ),
              AppListRow(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: 'Budget amount',
                subtitle: AppMoney.format(i.budgetAmount, currency: cur),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: widget.onOpenForm,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            container: true,
            label: 'Target from tomorrow, $from, becomes $to',
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.smd),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Target from tomorrow',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    from == to ? from : '$from → $to',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _saving ? null : _apply,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
