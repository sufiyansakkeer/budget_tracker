import 'package:equatable/equatable.dart';

/// When a tab expects to be settled (spec §4). Periods derived from it are a
/// view only: nothing stored depends on them.
sealed class SettleRhythm extends Equatable {
  const SettleRhythm();
}

/// No periods, no settle-up day, never overdue.
final class OnDemand extends SettleRhythm {
  const OnDemand();

  @override
  List<Object?> get props => const [];
}

/// Periods of [days] calendar days (1–365) starting on [anchor], also
/// repeating before it so older purchases get a period.
final class EveryDays extends SettleRhythm {
  final int days;

  /// First day of the first period.
  final DateTime anchor;

  const EveryDays({required this.days, required this.anchor});

  @override
  List<Object?> get props => [days, anchor];
}

/// A period runs from [day] (1–31, clamped to the month's length) of one
/// month to the day before [day] of the next.
final class MonthlyDay extends SettleRhythm {
  final int day;

  const MonthlyDay({required this.day});

  @override
  List<Object?> get props => [day];
}

/// The user picks each settle-up date. Nothing advances automatically.
final class ManualDate extends SettleRhythm {
  /// Settle-up day of the current period; null when none is set.
  final DateTime? nextSettleDate;

  /// The previous settle-up date: the current period starts here and
  /// purchases before it form one "earlier" period settling on it.
  final DateTime? anchor;

  const ManualDate({this.nextSettleDate, this.anchor});

  @override
  List<Object?> get props => [nextSettleDate, anchor];
}

/// A stretch of calendar days purchases are grouped into, and the day
/// payment is expected for it. All dates are at local midnight.
class SettlePeriod extends Equatable {
  /// First day; null for a period with no first day (the manual-date
  /// "earlier" period, or the first period before any settle date is set).
  final DateTime? start;

  /// Last day; null for an open period (manual date passed, none set).
  final DateTime? end;

  /// Settle-up day; null for an open period.
  final DateTime? settleUp;

  /// The manual-date "earlier" period: every purchase before the anchor,
  /// settling on the anchor. Only this period is "earlier"; a period whose
  /// [start] is null for another reason (no anchor set yet) is not.
  final bool isEarlier;

  const SettlePeriod({
    required this.start,
    this.end,
    this.settleUp,
    this.isEarlier = false,
  });

  /// True for the open period after a passed manual date: no settle-up day,
  /// never overdue.
  bool get isOpen => settleUp == null;

  @override
  List<Object?> get props => [start, end, settleUp, isEarlier];

  @override
  bool get stringify => true;
}
