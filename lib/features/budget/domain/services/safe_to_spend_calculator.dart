import 'dart:math' as math;

import '../../../../core/currency/money_math.dart';
import '../entities/safe_to_spend/commitment_occurrence.dart';
import '../entities/safe_to_spend/safe_to_spend_entity.dart';
import '../entities/safe_to_spend/safe_to_spend_forecast.dart';
import '../entities/safe_to_spend/safe_to_spend_input.dart';
import '../entities/safe_to_spend/safe_to_spend_reason.dart';
import '../entities/safe_to_spend/safe_to_spend_status.dart';
import 'budget_calculation_service.dart';

/// Pure safe-to-spend engine: how much of one budget can be spent today once
/// upcoming bills, money kept aside and the savings goal are protected.
///
/// No database, clock, UI or bills-feature dependencies. Day counts and the
/// daily division come from [BudgetCalculationService], so with no
/// deductions the daily figure is exactly the summary's
/// `dailySafeSpending`.
///
/// Money: every input amount is converted to integer units once
/// ([MoneyMath]); all sums, differences and comparisons run on the ints, and
/// only the final figures go back to doubles. Products of units with day
/// counts (the forecast, the over-today test) run in [BigInt], so no amount
/// [MoneyMath] accepts can overflow them. An amount it refuses throws an
/// [ArgumentError]. Nothing is floored here; display floors "safe" amounts
/// (`CurrencyFormatter.floorForDisplay`).
///
/// Running period, with A = budget − period spending, B = bills due,
/// C = kept aside, D = savings goal still to keep:
/// - raw = A − B − C − D (signed); free to spend = max(0, raw).
/// - today's discretionary = today's spending − set-aside bill payments
///   today; S0 = raw + today's discretionary (spendable at start of today).
/// - daily = max(0, (raw + today's discretionary) ÷ remaining days), fixed
///   for the whole day.
class SafeToSpendCalculator {
  final BudgetCalculationService _calculationService;

  const SafeToSpendCalculator(this._calculationService);

  SafeToSpendEntity calculate(SafeToSpendInput input) {
    final money = MoneyMath.forCurrency(input.currency);
    final today = DateTime(
      input.today.year,
      input.today.month,
      input.today.day,
    );
    final totalDays = _calculationService.daysInPeriod(
      startDate: input.startDate,
      endDate: input.endDate,
    );
    final daysUntilStart = BudgetCalculationService.calendarDaysBetween(
      today,
      input.startDate,
    );
    final daysAfterEnd = BudgetCalculationService.calendarDaysBetween(
      input.endDate,
      today,
    );
    final notStarted = daysUntilStart > 0;
    final ended = daysAfterEnd > 0;
    final running = !notStarted && !ended;

    final commitmentsAvailable = input.commitments != null;
    final occurrences = _dedupeAndSort(input.commitments ?? const []);

    // ── Integer units ──────────────────────────────────────────────────────
    final amountU = money.toUnits(input.budgetAmount);
    final periodSpentU = money.toUnits(input.periodSpent);
    final committedPeriodU = money.toUnits(input.committedSpentInPeriod);
    // Today's spending only belongs to this budget while it is running.
    final todaySpentU = running ? money.toUnits(input.todaySpent) : 0;
    final committedTodayU = running
        ? money.toUnits(input.committedSpentToday)
        : 0;
    final commitmentsU = money.sumUnits(occurrences.map((o) => o.amount));
    // Negative kept-aside or savings values (corrupt data) never add money.
    final reservedU = math.max(0, money.toUnits(input.reservedAmount ?? 0));
    // Contributions are not tracked, so the whole goal is still to keep.
    final savingsRemainingU = math.max(
      0,
      money.toUnits(input.savingsTarget ?? 0),
    );

    final availableU = amountU - periodSpentU;
    final rawU = availableU - commitmentsU - reservedU - savingsRemainingU;
    final discTodayU = todaySpentU - committedTodayU;
    final startOfTodayU = rawU + discTodayU;

    double amt(num units) => money.toAmount(units);

    var daysPassed = 0;
    var remainingDays = totalDays;
    var dailyU = 0.0;
    var baselineU = 0.0;
    SafeToSpendForecast? forecast;
    // Forecast margin and its divisor, kept exact for the status rules.
    BigInt? marginC;
    var completedDays = 0;
    final SafeToSpendStatus status;
    final reasons = <SafeToSpendReason>[];

    if (!commitmentsAvailable) reasons.add(const BillsUnavailableReason());

    if (running) {
      daysPassed = _calculationService.calculateDaysPassed(
        referenceDate: today,
        startDate: input.startDate,
        endDate: input.endDate,
      );
      remainingDays = _calculationService.calculateRemainingDays(
        referenceDate: today,
        startDate: input.startDate,
        endDate: input.endDate,
      );
      // Divided in units: the ints add exactly, so the only rounding is the
      // division itself.
      dailyU = math.max(
        0.0,
        _calculationService.calculateTodaySafeSpending(
          remainingBudget: rawU.toDouble(),
          todaySpending: discTodayU.toDouble(),
          remainingDays: remainingDays,
        ),
      );
      baselineU = math.max(
        0.0,
        _calculationService.calculateTodaySafeSpending(
          remainingBudget: availableU.toDouble(),
          todaySpending: discTodayU.toDouble(),
          remainingDays: remainingDays,
        ),
      );

      // ── Forecast (completed days only; today is still in progress) ────
      completedDays = daysPassed - 1;
      final discToDateU = periodSpentU - committedPeriodU;
      final discCompletedU = discToDateU - discTodayU;
      final minDays = input.thresholds.minForecastDays;
      if (completedDays >= minDays && discCompletedU > 0) {
        final c = BigInt.from(completedDays);
        // Every value below is multiplied by c so the average
        // (discCompletedU / c) never has to be rounded. BigInt: a unit
        // value times a day count can exceed 64 bits.
        final discCompletedB = BigInt.from(discCompletedU);
        final rawC = BigInt.from(rawU) * c;
        final todayC = BigInt.from(discTodayU) * c;
        final todayProjectedC = todayC > discCompletedB
            ? todayC
            : discCompletedB;
        final futureC =
            (todayProjectedC - todayC) +
            discCompletedB * BigInt.from(remainingDays - 1);
        final margin = rawC - futureC;
        marginC = margin;
        final projectedDiscC = BigInt.from(discToDateU) * c + futureC;
        final projectedPeriodC =
            BigInt.from(committedPeriodU + commitmentsU) * c + projectedDiscC;
        final averageU = _calculationService.calculateAverageDailySpending(
          totalSpent: discCompletedU.toDouble(),
          daysPassed: completedDays,
        );

        DateTime? exhaustion;
        if (margin.isNegative) {
          final leftAfterTodayC = rawC - (todayProjectedC - todayC);
          // A negative margin bounds the quotient by the remaining days.
          exhaustion = leftAfterTodayC.isNegative
              ? today
              : _addDays(
                  today,
                  1 + (leftAfterTodayC ~/ discCompletedB).toInt(),
                );
        }

        forecast = SafeToSpendForecast.reliable(
          completedDays: completedDays,
          averageDaily: amt(averageU),
          projectedDiscretionarySpending: amt(projectedDiscC / c),
          projectedPeriodSpending: amt(projectedPeriodC / c),
          projectedEndBalance: amt(
            (BigInt.from(amountU) * c - projectedPeriodC) / c,
          ),
          projectedMargin: amt(margin / c),
          exhaustionDate: exhaustion,
          paceRatio: dailyU > 0 ? averageU / dailyU : null,
        );
      } else {
        final int daysNeeded;
        if (completedDays < minDays) {
          daysNeeded = minDays - completedDays;
        } else {
          // Enough days, but no discretionary spending before today: today's
          // spending becomes history tomorrow.
          daysNeeded = discTodayU > 0 ? 1 : 0;
        }
        forecast = SafeToSpendForecast.insufficient(
          daysNeeded: daysNeeded,
          hasAnyExpense: discToDateU > 0,
          completedDays: completedDays,
        );
      }

      // ── Status (first match) ──────────────────────────────────────────
      final overDaily = _isOverDaily(discTodayU, startOfTodayU, remainingDays);
      final atRisk = marginC != null && marginC.isNegative;
      final thresholds = input.thresholds;
      if (availableU < 0) {
        status = SafeToSpendStatus.overBudget;
      } else if (startOfTodayU < 0) {
        status = SafeToSpendStatus.overcommitted;
      } else if (overDaily) {
        status = SafeToSpendStatus.overDailyAllowance;
      } else if (atRisk) {
        status = SafeToSpendStatus.budgetAtRisk;
      } else if (startOfTodayU == 0 ||
          (dailyU > 0 &&
              discTodayU >= thresholds.carefulDailyRatio * dailyU - 1e-6) ||
          (marginC != null &&
              marginC / BigInt.from(completedDays) <
                  thresholds.carefulMarginRatio * startOfTodayU) ||
          !commitmentsAvailable ||
          !input.currencyExcluded.isEmpty) {
        status = SafeToSpendStatus.spendingCarefully;
      } else {
        status = SafeToSpendStatus.onTrack;
      }

      // ── Reasons, hero priority order ──────────────────────────────────
      if (availableU < 0) reasons.add(OverBudgetByReason(amt(-availableU)));
      // Only when not over budget: then S0 < 0 can only come from bills or
      // money set aside. The amount is measured against what is left now
      // (the shortfall, −raw), the same figure the breakdown shows as
      // "… short"; S0 ≤ raw never makes it smaller than −S0.
      if (availableU >= 0 && startOfTodayU < 0) {
        reasons.add(OvercommittedByReason(amt(-rawU)));
      }
      if (overDaily) reasons.add(OverTodayReason(amt(discTodayU - dailyU)));
      if (atRisk) {
        reasons.add(
          AtRiskReason(
            averageDaily: forecast.averageDaily!,
            deficit: -forecast.projectedMargin!,
          ),
        );
      }
      _addDisclosureReasons(reasons, input);
      if (rawU <= 0 && availableU >= 0 && startOfTodayU >= 0) {
        reasons.add(const NothingFreeToSpendReason());
      }
      if (baselineU > dailyU) {
        reasons.add(
          AllowanceReducedReason(
            amount: amt(baselineU - dailyU),
            billsTotal: amt(commitmentsU),
            reserved: input.reservedAmount == null ? null : amt(reservedU),
            savings: input.savingsTarget == null
                ? null
                : amt(savingsRemainingU),
          ),
        );
      }
      if (committedTodayU > 0) {
        reasons.add(BillPaymentsTodayReason(amt(committedTodayU)));
      }
      _addBillsDue(reasons, occurrences, commitmentsU, amt);
      if (!forecast.isReliable) {
        reasons.add(
          ForecastInsufficientReason(
            daysNeeded: forecast.daysNeeded,
            hasAnyExpense: forecast.hasAnyExpense,
          ),
        );
      }
    } else if (notStarted) {
      status = SafeToSpendStatus.notStarted;
      daysPassed = 0;
      remainingDays = totalDays;
      if (availableU < 0) reasons.add(OverBudgetByReason(amt(-availableU)));
      _addDisclosureReasons(reasons, input);
      _addBillsDue(reasons, occurrences, commitmentsU, amt);
    } else {
      status = SafeToSpendStatus.periodEnded;
      daysPassed = totalDays;
      remainingDays = 0;
      // Bills are irrelevant to a finished period; only the result counts.
      reasons.clear();
      if (availableU < 0) reasons.add(OverBudgetByReason(amt(-availableU)));
    }

    return SafeToSpendEntity(
      budgetId: input.budgetId,
      budgetName: input.budgetName,
      currency: input.currency,
      startDate: input.startDate,
      endDate: input.endDate,
      today: today,
      totalDays: totalDays,
      daysPassed: daysPassed,
      remainingDays: remainingDays,
      daysUntilStart: notStarted ? daysUntilStart : 0,
      budgetAmount: amt(amountU),
      periodSpent: amt(periodSpentU),
      availableBalance: amt(availableU),
      upcomingCommitments: amt(commitmentsU),
      commitments: occurrences,
      reservedAmount: input.reservedAmount == null ? null : amt(reservedU),
      savingsTarget: input.savingsTarget,
      remainingSavingsTarget: input.savingsTarget == null
          ? null
          : amt(savingsRemainingU),
      rawSpendable: amt(rawU),
      freeToSpend: amt(math.max(0, rawU)),
      shortfall: amt(math.max(0, -rawU)),
      spendableAtStartOfToday: amt(startOfTodayU),
      todaySpent: amt(todaySpentU),
      committedSpentToday: amt(committedTodayU),
      committedSpentInPeriod: amt(committedPeriodU),
      todayDiscretionary: amt(discTodayU),
      dailySafeToSpend: amt(dailyU),
      remainingToday: amt(math.max(0.0, dailyU - discTodayU)),
      overToday: amt(math.max(0.0, discTodayU - dailyU)),
      baselineDaily: amt(baselineU),
      allowanceReduction: amt(math.max(0.0, baselineU - dailyU)),
      forecast: forecast,
      status: status,
      reasons: List.unmodifiable(reasons),
      unlinked: input.unlinked,
      currencyExcluded: input.currencyExcluded,
      commitmentsAvailable: commitmentsAvailable,
    );
  }

  /// Whether today's discretionary spending is above today's safe amount,
  /// decided on integers: disc > S0 ÷ days ⟺ disc × days > S0 (when S0 > 0;
  /// otherwise today's amount is 0 and any spending is over). The product is
  /// a [BigInt] so it cannot overflow.
  static bool _isOverDaily(int discTodayU, int startOfTodayU, int days) {
    if (startOfTodayU <= 0) return discTodayU > 0;
    return BigInt.from(discTodayU) * BigInt.from(days) >
        BigInt.from(startOfTodayU);
  }

  static void _addDisclosureReasons(
    List<SafeToSpendReason> reasons,
    SafeToSpendInput input,
  ) {
    if (!input.unlinked.isEmpty) {
      reasons.add(
        BillsNotLinkedReason(
          count: input.unlinked.count,
          total: input.unlinked.total,
        ),
      );
    }
    if (!input.currencyExcluded.isEmpty) {
      reasons.add(
        BillsCurrencyExcludedReason(
          count: input.currencyExcluded.count,
          totalsByCurrency: input.currencyExcluded.totalsByCurrency,
        ),
      );
    }
  }

  static void _addBillsDue(
    List<SafeToSpendReason> reasons,
    List<CommitmentOccurrence> occurrences,
    int commitmentsU,
    double Function(num units) amt,
  ) {
    if (occurrences.isEmpty) return;
    reasons.add(
      BillsDueReason(
        total: amt(commitmentsU),
        count: occurrences.length,
        nextDue: occurrences.first.dueDate,
      ),
    );
  }

  /// One entry per (bill, due date), earliest first; ties keep input order.
  static List<CommitmentOccurrence> _dedupeAndSort(
    List<CommitmentOccurrence> commitments,
  ) {
    final seen = <String>{};
    final unique = <CommitmentOccurrence>[];
    for (final o in commitments) {
      final d = o.dueDate;
      if (seen.add('${o.billId}|${d.year}-${d.month}-${d.day}')) unique.add(o);
    }
    final indexed = unique.asMap().entries.toList()
      ..sort((a, b) {
        final byDate = BudgetCalculationService.calendarDaysBetween(
          b.value.dueDate,
          a.value.dueDate,
        );
        return byDate != 0 ? byDate : a.key.compareTo(b.key);
      });
    return List.unmodifiable(indexed.map((e) => e.value));
  }

  /// Calendar arithmetic (not Duration), so DST days still advance one date.
  static DateTime _addDays(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);
}
