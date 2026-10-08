import 'package:intl/intl.dart';

import '../../../../core/currency/currency_formatter.dart';
import '../../../budget/domain/entities/safe_to_spend/commitment_occurrence.dart';
import '../../../budget/domain/entities/safe_to_spend/currency_excluded_summary.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_forecast.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_reason.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_status.dart';
import '../../../budget/domain/entities/safe_to_spend/unlinked_commitment_summary.dart';

/// Every user-facing string about Today's Safe Spending, built from the
/// engine's [SafeToSpendEntity]. Pure presentation: it formats figures the
/// engine computed and never derives new ones.
///
/// Amounts the user is told they can spend (today's amount, left today,
/// free to spend) are floored to the digits shown ([safeAmount]); every
/// other figure is shown to the currency's minor unit when it has a fraction
/// ([amount]), so OMR 7.600 never reads "8".
abstract final class SafeToSpendCopy {
  static final DateFormat _short = DateFormat('d MMM');
  static final DateFormat _long = DateFormat('d MMMM');

  // ── Formatting ───────────────────────────────────────────────────────────

  /// "31 Oct".
  static String date(DateTime d) => _short.format(d);

  /// "31 October", for screen readers.
  static String spokenDate(DateTime d) => _long.format(d);

  /// An exact figure: the currency's decimals when it has a fraction at that
  /// precision, otherwise none. Negative values get a leading "−".
  static String amount(double value, String currency) {
    final digits = CurrencyFormatter.decimalDigitsFor(currency);
    final factor = _pow10(digits);
    final units = (value.abs() * factor).round();
    final text = CurrencyFormatter.format(
      units / factor,
      code: currency,
      decimalDigits: units % factor == 0 ? 0 : digits,
    );
    return units != 0 && value < 0 ? '−$text' : text;
  }

  /// Decimals to show an exact [value] with: the currency's when it has a
  /// fraction at that precision, otherwise none.
  static int digitsFor(double value, String currency) {
    final digits = CurrencyFormatter.decimalDigitsFor(currency);
    final factor = _pow10(digits);
    return (value.abs() * factor).round() % factor == 0 ? 0 : digits;
  }

  /// A "safe" figure, floored to the digits shown (never more than is safe).
  static String safeAmount(double value, String currency) =>
      CurrencyFormatter.formatFloored(value, code: currency);

  static int _pow10(int digits) {
    var f = 1;
    for (var i = 0; i < digits; i++) {
      f *= 10;
    }
    return f;
  }

  static String _count(int n, String singular, [String? plural]) =>
      '$n ${n == 1 ? singular : (plural ?? '${singular}s')}';

  // ── Status ───────────────────────────────────────────────────────────────

  static String statusLabel(SafeToSpendStatus status) => switch (status) {
    SafeToSpendStatus.onTrack => 'On track',
    SafeToSpendStatus.spendingCarefully => 'Spend carefully',
    SafeToSpendStatus.overDailyAllowance => "Over today's amount",
    SafeToSpendStatus.budgetAtRisk => 'At risk',
    SafeToSpendStatus.overcommitted => 'Overcommitted',
    SafeToSpendStatus.overBudget => 'Over budget',
    SafeToSpendStatus.notStarted => 'Not started',
    SafeToSpendStatus.periodEnded => 'Ended',
  };

  // ── Reasons ──────────────────────────────────────────────────────────────

  /// The copy for one reason, or null for reasons shown elsewhere rather
  /// than as a sentence (bill payments caption, bills due row, forecast).
  static String? reason(SafeToSpendReason reason, SafeToSpendEntity e) {
    final cur = e.currency;
    return switch (reason) {
      BillsUnavailableReason() =>
        "Bills couldn't be loaded, so they aren't included. Today's amount "
            'may be too high.',
      OverBudgetByReason(:final amount) =>
        "You've spent ${SafeToSpendCopy.amount(amount, cur)} more than this "
            "budget's amount.",
      OvercommittedByReason(:final amount) =>
        'Bills and money set aside are ${SafeToSpendCopy.amount(amount, cur)} '
            "more than what's left in this budget.",
      OverTodayReason(:final amount) =>
        "You've spent ${SafeToSpendCopy.amount(amount, cur)} more than "
            "today's safe amount. Tomorrow's amount will be lower.",
      AtRiskReason(:final averageDaily, :final deficit) => atRisk(
        averageDaily: averageDaily,
        deficit: deficit,
        e: e,
      ),
      BillsNotLinkedReason(:final count, :final total) => notLinked(
        UnlinkedCommitmentSummary(count: count, total: total),
        cur,
      ),
      BillsCurrencyExcludedReason(:final count, :final totalsByCurrency) =>
        currencyExcluded(
          CurrencyExcludedSummary(
            count: count,
            totalsByCurrency: totalsByCurrency,
          ),
          cur,
        ),
      NothingFreeToSpendReason() =>
        e.totalDeductions > 0
            ? 'Nothing is free to spend after bills and money set aside.'
            : 'Nothing is left to spend in this budget.',
      AllowanceReducedReason(:final amount) =>
        "Today's amount is ${SafeToSpendCopy.amount(amount, cur)} lower "
            'because of bills and money set aside.',
      BillPaymentsTodayReason() => null,
      BillsDueReason() => null,
      ForecastInsufficientReason() => null,
    };
  }

  /// The at-risk sentence. It names the same quantity as the forecast's
  /// "Projected left / short" row: when the budget itself is projected to
  /// end short, by that amount; when it would only eat into what is kept
  /// aside or the savings goal (the projected end balance stays ≥ 0), it
  /// says so instead of calling the budget short.
  static String atRisk({
    required double averageDaily,
    required double deficit,
    required SafeToSpendEntity e,
  }) {
    final cur = e.currency;
    final pace = 'At your average so far (${amount(averageDaily, cur)} a day)';
    final endBalance = e.forecast?.projectedEndBalance;
    if (endBalance == null || endBalance < 0) {
      final short = endBalance == null ? deficit : -endBalance;
      return '$pace, this budget would end about ${amount(short, cur)} short.';
    }
    final kept = (e.reservedAmount ?? 0) > 0;
    final savings = (e.remainingSavingsTarget ?? 0) > 0;
    final what = kept && savings
        ? 'the money kept aside and your savings goal'
        : savings
        ? 'your savings goal'
        : 'the money kept aside';
    return "$pace, you'd use about ${amount(deficit, cur)} of $what.";
  }

  /// The hero's one explanation line: the most important reason (engine
  /// order) that is explained in words. Bills not linked, in another
  /// currency, or unavailable get their own notice card right below the
  /// breakdown, with an action, so the hero does not repeat them.
  static String? heroExplanation(SafeToSpendEntity e) {
    for (final r in e.reasons) {
      if (r is BillsUnavailableReason ||
          r is BillsNotLinkedReason ||
          r is BillsCurrencyExcludedReason) {
        continue;
      }
      final text = reason(r, e);
      if (text != null) return text;
    }
    // Free money remains, but less than one minor unit a day of it.
    final daily = CurrencyFormatter.floorForDisplay(
      e.dailySafeToSpend,
      code: e.currency,
    );
    if (e.isRunning && daily.amount == 0 && e.rawSpendable > 0) {
      final digits = CurrencyFormatter.decimalDigitsFor(e.currency);
      final unit = CurrencyFormatter.format(
        1 / _pow10(digits),
        code: e.currency,
        decimalDigits: digits,
      );
      return e.totalDeductions > 0
          ? 'Less than $unit a day is left after bills and money set aside.'
          : 'Less than $unit a day is left in this budget.';
    }
    return null;
  }

  /// Caption under the hero metrics when set-aside bills were paid today.
  static String billPaymentsToday(SafeToSpendEntity e) =>
      'Bill payments today (${amount(e.committedSpentToday, e.currency)}) are '
      "already counted in your bills and don't use today's amount.";

  /// "{n} upcoming bills (₹1,500) aren't linked to a budget, …".
  static String notLinked(UnlinkedCommitmentSummary s, String currency) {
    final one = s.count == 1;
    return '${_count(s.count, 'upcoming bill')} '
        '(${amount(s.total, currency)}) ${one ? "isn't" : "aren't"} linked '
        'to a budget, so nothing is set aside for '
        '${one ? 'it' : 'them'}.';
  }

  /// "1 linked bill in USD isn't included because this budget uses INR."
  static String currencyExcluded(
    CurrencyExcludedSummary s,
    String budgetCurrency,
  ) {
    final codes = s.totalsByCurrency.keys.toList()..sort();
    final one = s.count == 1;
    return '${_count(s.count, 'linked bill')} in ${codes.join(', ')} '
        "${one ? "isn't" : "aren't"} included because this budget uses "
        '$budgetCurrency.';
  }

  // ── Hero ─────────────────────────────────────────────────────────────────

  /// "Groceries · until 31 Oct".
  static String heroSubline(SafeToSpendEntity e) =>
      '${e.budgetName} · until ${date(e.endDate)}';

  /// One label for the hero's figures, read as a single unit.
  static String heroSemantics(SafeToSpendEntity e) {
    final buffer = StringBuffer(
      "Today's Safe Spending, ${safeAmount(e.dailySafeToSpend, e.currency)}. "
      '${statusLabel(e.status)}. '
      '${e.budgetName}, until ${spokenDate(e.endDate)}. '
      'Spent today ${amount(e.todayDiscretionary, e.currency)}, ',
    );
    buffer.write(
      e.overToday > 0
          ? 'over by ${amount(e.overToday, e.currency)}.'
          : 'left today ${safeAmount(e.remainingToday, e.currency)}.',
    );
    if (e.committedSpentToday > 0) buffer.write(' ${billPaymentsToday(e)}');
    final explanation = heroExplanation(e);
    if (explanation != null) buffer.write(' $explanation');
    return buffer.toString();
  }

  // ── Not running ──────────────────────────────────────────────────────────

  static String notRunningTitle(SafeToSpendEntity e) =>
      e.status == SafeToSpendStatus.notStarted
      ? 'This budget starts ${date(e.startDate)}'
      : 'This budget ended ${date(e.endDate)}';

  /// "Starts 1 Nov. ₹15,000 in bills will be set aside from this budget." /
  /// "Ended 31 Oct with ₹2,000 left."
  static String notRunningMessage(SafeToSpendEntity e) {
    if (e.status == SafeToSpendStatus.notStarted) {
      final start = 'Starts ${date(e.startDate)}.';
      if (e.upcomingCommitments > 0) {
        return '$start ${amount(e.upcomingCommitments, e.currency)} in bills '
            'will be set aside from this budget.';
      }
      return "$start Today's Safe Spending will appear once the period "
          'begins.';
    }
    final ended = 'Ended ${date(e.endDate)}';
    if (e.availableBalance < 0) {
      return '$ended, ${amount(-e.availableBalance, e.currency)} over.';
    }
    return '$ended with ${amount(e.availableBalance, e.currency)} left.';
  }

  // ── Breakdown ────────────────────────────────────────────────────────────

  /// "Bills due by 31 Oct (2)".
  static String billsDueLabel(SafeToSpendEntity e) =>
      'Bills due by ${date(e.endDate)} (${e.commitments.length})';

  /// "Rent · 28 Oct · ₹12,000".
  static String occurrenceLine(CommitmentOccurrence o, String currency) =>
      '${o.title} · ${date(o.dueDate)} · ${amount(o.amount, currency)}';

  static String occurrenceSemantics(CommitmentOccurrence o, String currency) =>
      '${o.title}, due ${spokenDate(o.dueDate)}, ${amount(o.amount, currency)}'
      '${o.isOverdue ? ', overdue' : ''}';

  /// "Free to spend until 31 Oct".
  static String freeToSpendLabel(SafeToSpendEntity e) =>
      'Free to spend until ${date(e.endDate)}';

  /// The "= Free to spend" value: floored, or "{amt} short".
  static String freeToSpendValue(SafeToSpendEntity e) => e.shortfall > 0
      ? '${amount(e.shortfall, e.currency)} short'
      : safeAmount(e.freeToSpend, e.currency);

  // ── Forecast ─────────────────────────────────────────────────────────────

  /// "Forecast after 2 more days" / "Forecast appears after your first
  /// expense in this budget."
  static String forecastInsufficient(SafeToSpendForecast f) => f.daysNeeded > 0
      ? 'Forecast after ${_count(f.daysNeeded, 'more day')}'
      : 'Forecast appears after your first expense in this budget.';

  /// "Free money runs out around 24 Oct".
  static String exhaustion(DateTime d) =>
      'Free money runs out around ${date(d)}';
}
