import '../../../../core/dates/calendar_dates.dart';
import '../../../expenses/domain/entities/expense_entity.dart';
import '../entities/tab_payment.dart';

/// The one oldest-first order every Pay later calculation uses, so the
/// allocator, the ledger and a dry run never disagree about which purchase
/// a payment pays (spec §5, FIFO). It matches the order the repository
/// reads rows in, and always ends with the id: Drift keeps dates to the
/// second and an expense's time to the minute, so two rows can tie on
/// everything else, and `List.sort` isn't stable.
abstract final class FifoOrder {
  /// Purchase date (the calendar day), then time, then created, then id.
  static int purchases(ExpenseEntity a, ExpenseEntity b) {
    final byDate = a.date.dateOnly.compareTo(b.date.dateOnly);
    if (byDate != 0) return byDate;
    final byTime = a.time.compareTo(b.time);
    if (byTime != 0) return byTime;
    final byCreated = a.createdAt.compareTo(b.createdAt);
    return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
  }

  /// Paid date (the calendar day), then created, then id.
  static int payments(TabPayment a, TabPayment b) {
    final byDate = a.paidDate.dateOnly.compareTo(b.paidDate.dateOnly);
    if (byDate != 0) return byDate;
    final byCreated = a.createdAt.compareTo(b.createdAt);
    return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
  }
}
