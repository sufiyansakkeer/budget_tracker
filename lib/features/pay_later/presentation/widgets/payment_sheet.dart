import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/currency/currency_formatter.dart';
import '../../../../core/currency/money_input.dart';
import '../../../../core/currency/money_math.dart';
import '../../../../core/dates/calendar_dates.dart';
import '../../../../core/events/refresh_bus.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_disclosure.dart';
import '../../../../core/widgets/app_money.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../../../expenses/presentation/widgets/expense_amount_field.dart';
import '../../domain/entities/pay_later_failure.dart';
import '../../domain/entities/tab_ledger.dart';
import '../../domain/entities/tab_payment.dart';
import '../../domain/usecases/tab_payment_usecase.dart';
import '../pay_later_failure_copy.dart';
import 'tab_tile.dart';
import 'tab_visuals.dart';

/// Records a payment on a tab, or edits one (spec §7 "Payment sheet"):
/// amount, the day it was paid (not after today), a note and, for a new
/// payment, "Choose what this pays". Shows what the tab will owe after it
/// before saving.
///
/// A new payment's id is made once, when the sheet opens, and sent with
/// every save attempt: if a save times out and is tried again, the use case
/// finds the first one instead of recording it twice. Save is disabled while
/// a save runs, but that is only for the eye; the id is the real guard.
///
/// On success it notifies [RefreshBuses.payLater] and closes with what to
/// tell the user ("Payment recorded"); dismissed, it closes with null.
class PaymentSheet extends StatefulWidget {
  final TabLedger ledger;
  final TabPaymentUseCase payments;

  /// The payment to edit; null records a new one.
  final PaymentLine? editing;

  /// Opened from "Settle all": the amount starts at what the tab owes.
  final bool settleAll;

  /// Expense categories by id, to name purchases that have no note.
  final Map<String, ExpenseCategory> categories;
  final DateTime Function() clock;

  const PaymentSheet({
    super.key,
    required this.ledger,
    required this.payments,
    this.editing,
    this.settleAll = false,
    this.categories = const {},
    required this.clock,
  });

  static Future<String?> show(
    BuildContext context, {
    required TabLedger ledger,
    required TabPaymentUseCase payments,
    PaymentLine? editing,
    bool settleAll = false,
    Map<String, ExpenseCategory> categories = const {},
    DateTime Function()? clock,
  }) => AppBottomSheet.show<String>(
    context: context,
    builder: (_) => PaymentSheet(
      ledger: ledger,
      payments: payments,
      editing: editing,
      settleAll: settleAll,
      categories: categories,
      clock: clock ?? DateTime.now,
    ),
  );

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  late final String _paymentId;
  late final MoneyMath _money;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _date;

  /// Chosen purchases' expense ids.
  final Set<String> _chosen = {};
  bool _saving = false;

  /// Save was tried: an empty amount now says so.
  bool _submitted = false;

  /// Why the last save failed.
  String? _saveError;

  String get _currency => widget.ledger.tab.currency;
  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing?.payment;
    _paymentId = editing?.id ?? const Uuid().v4();
    _money = MoneyMath.forCurrency(_currency);
    _amount = TextEditingController(
      text: editing != null
          ? MoneyInput.forInput(editing.amount)
          : widget.settleAll
          ? MoneyInput.forInput(widget.ledger.owed)
          : '',
    );
    _note = TextEditingController(text: editing?.note ?? '');
    _date = (editing?.paidDate ?? widget.clock()).dateOnly;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  // ── Money ──────────────────────────────────────────────────────────────

  int get _owedUnits => _money.toUnits(widget.ledger.owed);

  /// The typed amount in units when it is a number above zero within the
  /// app's limit; otherwise null.
  int? get _typedUnits {
    final value = double.tryParse(_amount.text.trim());
    if (value == null || !MoneyMath.isWithinLimit(value)) return null;
    final units = _money.toUnits(value);
    return units > 0 ? units : null;
  }

  /// The most this payment may be: what the tab owes, plus (when editing)
  /// what this payment already covers. Only checked for a new payment or a
  /// raised one (see [_amountError]), as the use case does.
  int get _limitUnits {
    final editing = widget.editing;
    if (editing == null) return _owedUnits;
    final applied =
        _money.toUnits(editing.payment.amount) -
        _money.toUnits(editing.unapplied);
    return _owedUnits + applied;
  }

  /// The tab's balance after saving, signed: > 0 owed, < 0 in credit.
  /// A new payment: owed − amount, never below zero (as
  /// [TabPaymentUseCase.owedAfter]). An edit: purchases − payments with this
  /// payment's new amount.
  int get _balanceAfterUnits {
    final typed = _typedUnits;
    final editing = widget.editing;
    if (editing == null) return math.max(0, _owedUnits - (typed ?? 0));
    final old = _money.toUnits(editing.payment.amount);
    final net = _owedUnits - _money.toUnits(widget.ledger.credit);
    return net + old - (typed ?? old);
  }

  String _format(int units) =>
      AppMoney.format(_money.toAmount(units), currency: _currency);

  /// What is wrong with the amount, or null. Over the limit shows as soon as
  /// it is typed (for an edit, only when the amount is raised); empty or
  /// zero only once Save was tried.
  String? get _amountError {
    final text = _amount.text.trim();
    final decimals = MoneyInput.decimalsError(text, _currency);
    if (decimals != null) return decimals;
    final typed = _typedUnits;
    if (typed == null) {
      return _submitted || text.isNotEmpty
          ? 'Enter an amount above zero.'
          : null;
    }
    // An edit is only checked when it raises the amount, as the use case
    // does: a payment holding credit keeps its amount when just its date or
    // note changes, even though that amount is above owed + applied.
    final editing = widget.editing;
    final raised =
        editing == null || typed > _money.toUnits(editing.payment.amount);
    if (raised && typed > _limitUnits) {
      return _isEdit
          ? 'This payment can be up to ${_format(_limitUnits)}.'
          : 'You owe ${_format(_owedUnits)} on this tab.';
    }
    return null;
  }

  // ── Choosing purchases ────────────────────────────────────────────────

  List<PurchaseLine> get _owing => [
    for (final line in widget.ledger.purchases)
      if (_money.toUnits(line.owes) > 0) line,
  ];

  void _toggle(PurchaseLine line, bool chosen) {
    setState(() {
      if (chosen) {
        _chosen.add(line.expense.id);
      } else {
        _chosen.remove(line.expense.id);
      }
      final total = _money.sumUnits([
        for (final l in _owing)
          if (_chosen.contains(l.expense.id)) l.owes,
      ]);
      _amount.text = total == 0
          ? ''
          : MoneyInput.forInput(_money.toAmount(total));
      _saveError = null;
    });
  }

  // ── Saving ─────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final today = widget.clock().dateOnly;
    final first = DateTime(2000);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(today) ? today : _date,
      firstDate: _date.isBefore(first) ? _date : first,
      lastDate: today,
      helpText: 'Paid on',
    );
    if (picked != null && mounted) {
      setState(() {
        _date = picked.dateOnly;
        _saveError = null;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _submitted = true;
      _saveError = null;
    });
    final units = _typedUnits;
    if (units == null || _amountError != null) return;
    setState(() => _saving = true);

    final amount = _money.toAmount(units);
    final note = _note.text.trim();
    final settles = _balanceAfterUnits == 0;
    final editing = widget.editing?.payment;
    final PayLaterResult<TabPayment> result;
    if (editing != null) {
      result = await widget.payments.update(
        editing.copyWith(
          amount: amount,
          paidDate: _date,
          note: note.isEmpty ? null : note,
          clearNote: note.isEmpty,
        ),
      );
    } else {
      result = await widget.payments.record(
        paymentId: _paymentId,
        tabId: widget.ledger.tab.id,
        amount: amount,
        paidDate: _date,
        note: note.isEmpty ? null : note,
        chosenExpenseIds: {..._chosen},
      );
    }
    if (!mounted) return;
    switch (result) {
      case PayLaterSuccess():
        RefreshBuses.payLater.notifyChanged();
        Navigator.of(context).pop(
          editing != null
              ? 'Payment updated'
              : (widget.settleAll && settles)
              ? 'Tab settled'
              : 'Payment recorded',
        );
      case PayLaterError(:final failure):
        debugPrint(
          '[error] ${editing != null ? 'Editing' : 'Recording'} a payment: '
          '${failure.message}',
        );
        setState(() {
          _saving = false;
          _saveError = failure.shown(
            editing != null
                ? "Couldn't save the payment. Try again."
                : "Couldn't record the payment. Try again.",
          );
        });
    }
  }

  // ── Layout ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tab = widget.ledger.tab;
    final owing = _owing;
    final balance = _balanceAfterUnits;
    final today = widget.clock().dateOnly;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetHeader(
          title: _isEdit
              ? 'Edit payment'
              : widget.settleAll
              ? 'Settle all'
              : 'Record payment',
          subtitle: '${tab.name} · You owe ${_format(_owedUnits)}',
        ),
        // A column, not a lazy list: the amount field stays alive while the
        // purchases to choose from are scrolled into view.
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xs),
                ExpenseAmountField(
                  key: const Key('paymentAmountField'),
                  controller: _amount,
                  currencySymbol: CurrencyFormatter.symbolFor(_currency),
                  maxDecimals: MoneyInput.maxDecimals(_currency),
                  autofocus: !_isEdit && !widget.settleAll,
                  errorText: _amountError,
                  onChanged: (_) => setState(() => _saveError = null),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  balance < 0
                      ? 'In credit after: ${_format(-balance)}'
                      : 'Owed after: ${_format(balance)}',
                  key: const Key('paymentOwedAfter'),
                  style: muted,
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  key: const Key('paymentDateButton'),
                  onPressed: _saving ? null : _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    _date == today
                        ? 'Paid today'
                        : 'Paid ${TabTile.formatDay(_date, today: today)}',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('paymentNoteField'),
                  controller: _note,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    counterText: '',
                  ),
                ),
                if (!_isEdit && owing.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppDisclosure(
                    title: 'Choose what this pays',
                    summary: _chosen.isEmpty
                        ? 'Otherwise the oldest purchases are paid first'
                        : '${_chosen.length} chosen',
                    child: Column(
                      children: [
                        for (final line in owing) _choiceRow(line, today),
                      ],
                    ),
                  ),
                ],
                if (_saveError != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _saveError!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: FilledButton(
            key: const Key('paymentSaveButton'),
            onPressed: _saving ? null : _save,
            child: Text(
              _isEdit
                  ? 'Save changes'
                  : widget.settleAll
                  ? 'Settle all'
                  : 'Record payment',
            ),
          ),
        ),
      ],
    );
  }

  Widget _choiceRow(PurchaseLine line, DateTime today) {
    final expense = line.expense;
    final owes = AppMoney.format(line.owes, currency: _currency);
    return CheckboxListTile(
      key: Key('paymentChoose_${expense.id}'),
      contentPadding: EdgeInsets.zero,
      value: _chosen.contains(expense.id),
      onChanged: _saving ? null : (v) => _toggle(line, v ?? false),
      title: Text(
        purchaseTitle(
          expense,
          categoryName: widget.categories[expense.categoryId]?.name,
        ),
      ),
      subtitle: Text(
        '${TabTile.formatDay(expense.date, today: today)} · owes $owes',
      ),
    );
  }
}
