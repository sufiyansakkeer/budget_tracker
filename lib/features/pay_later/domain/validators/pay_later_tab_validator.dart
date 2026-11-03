import '../../../../core/dates/calendar_dates.dart';
import '../entities/pay_later_tab.dart';
import '../entities/settle_rhythm.dart';

/// Checks a [PayLaterTab] before it is saved (spec §3).
abstract final class PayLaterTabValidator {
  /// The user-facing message for the first problem, or null when valid.
  ///
  /// A manual settle date in the past is only refused on [isCreate]. An
  /// edit accepts any date, past ones included, so a tab whose date has
  /// passed still saves when only its name or reminder changes (it then
  /// asks for its next settle-up date, spec §4).
  static String? validate(
    PayLaterTab tab, {
    required DateTime today,
    required bool isCreate,
  }) {
    final name = tab.name.trim();
    if (name.isEmpty || name.length > 100) {
      return 'Enter a name of 1 to 100 characters.';
    }
    if (tab.currency.trim().isEmpty) return 'Choose a currency.';
    switch (tab.rhythm) {
      case OnDemand():
        break;
      case EveryDays(:final days):
        if (days < 1 || days > 365) {
          return 'Enter a number of days from 1 to 365.';
        }
      case MonthlyDay(:final day):
        if (day < 1 || day > 31) {
          return 'Choose a day of the month from 1 to 31.';
        }
      case ManualDate(:final nextSettleDate):
        if (isCreate &&
            nextSettleDate != null &&
            nextSettleDate.dateOnly.isBefore(today.dateOnly)) {
          return 'Choose a settle-up date that is today or later.';
        }
    }
    if (tab.reminderOffsetDays < 0 || tab.reminderOffsetDays > 7) {
      return 'Choose a reminder from 0 to 7 days before.';
    }
    return null;
  }
}
