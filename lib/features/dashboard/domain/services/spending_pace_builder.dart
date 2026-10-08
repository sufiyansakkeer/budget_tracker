import '../../../../core/currency/money_math.dart';
import '../../../budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import '../entities/spending_pace.dart';

/// Builds a [SpendingPace] from a running budget's safe-to-spend result and
/// its discretionary spending per calendar day. Pure: no clock, no storage.
///
/// Money is summed in integer units ([MoneyMath]); the one division (the
/// even pace to date) runs on the units and floors, so the plan is never
/// shown higher than it is.
abstract final class SpendingPaceBuilder {
  /// Returns `null` outside the running period.
  ///
  /// [dailyDiscretionary] maps a calendar day (time of day ignored) to that
  /// day's spending without set-aside bill payments; days without spending
  /// may be absent.
  static SpendingPace? build({
    required SafeToSpendEntity safeToSpend,
    required Map<DateTime, double> dailyDiscretionary,
  }) {
    final e = safeToSpend;
    if (!e.isRunning || e.totalDays <= 0) return null;
    final money = MoneyMath.forCurrency(e.currency);

    // Re-key by calendar day so stored times of day never split a day.
    final byDay = <DateTime, int>{};
    dailyDiscretionary.forEach((day, amount) {
      final key = DateTime(day.year, day.month, day.day);
      byDay[key] = (byDay[key] ?? 0) + money.toUnits(amount);
    });

    final start = DateTime(
      e.startDate.year,
      e.startDate.month,
      e.startDate.day,
    );
    final cumulativeU = <int>[];
    var runningU = 0;
    for (var i = 0; i < e.daysPassed; i++) {
      // Calendar stepping, so a daylight-saving day is still one day.
      final day = DateTime(start.year, start.month, start.day + i);
      runningU += byDay[day] ?? 0;
      cumulativeU.add(runningU);
    }

    final discretionarySoFarU =
        money.toUnits(e.periodSpent) - money.toUnits(e.committedSpentInPeriod);
    final plannedTotalU = money.toUnits(e.rawSpendable) + discretionarySoFarU;
    final plannedToDateU = plannedTotalU <= 0
        ? 0
        : (BigInt.from(plannedTotalU) *
                  BigInt.from(e.daysPassed) ~/
                  BigInt.from(e.totalDays))
              .toInt();

    return SpendingPace(
      currency: e.currency,
      totalDays: e.totalDays,
      daysPassed: e.daysPassed,
      cumulative: List.unmodifiable(cumulativeU.map(money.toAmount)),
      plannedTotal: money.toAmount(plannedTotalU),
      plannedToDate: money.toAmount(plannedToDateU),
      actualToDate: money.toAmount(runningU),
    );
  }
}
