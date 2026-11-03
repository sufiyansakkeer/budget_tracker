/// Bill status, category, and recurrence type enumerations.
library;

/// Display status of a bill — calculated from isPaid + dueDate, never persisted.
enum BillStatus { upcoming, dueToday, overdue, paid }

/// Category of a bill.
enum BillCategory {
  rent,
  utilities,
  electricity,
  water,
  internet,
  phone,
  emi,
  insurance,
  subscription,
  education,
  healthcare,
  government,
  creditCard,
  other,
}

/// Recurrence type for recurring bills.
enum RecurrenceType { none, weekly, monthly, yearly }

/// Human-readable labels for bill categories.
extension BillCategoryLabel on BillCategory {
  String get label {
    switch (this) {
      case BillCategory.rent:
        return 'Rent';
      case BillCategory.utilities:
        return 'Utilities';
      case BillCategory.electricity:
        return 'Electricity';
      case BillCategory.water:
        return 'Water';
      case BillCategory.internet:
        return 'Internet';
      case BillCategory.phone:
        return 'Phone';
      case BillCategory.emi:
        return 'EMI';
      case BillCategory.insurance:
        return 'Insurance';
      case BillCategory.subscription:
        return 'Subscription';
      case BillCategory.education:
        return 'Education';
      case BillCategory.healthcare:
        return 'Healthcare';
      case BillCategory.government:
        return 'Government';
      case BillCategory.creditCard:
        return 'Credit Card';
      case BillCategory.other:
        return 'Other';
    }
  }
}

/// Human-readable labels for recurrence types.
extension RecurrenceTypeLabel on RecurrenceType {
  String get label {
    switch (this) {
      case RecurrenceType.none:
        return 'One-time';
      case RecurrenceType.weekly:
        return 'Weekly';
      case RecurrenceType.monthly:
        return 'Monthly';
      case RecurrenceType.yearly:
        return 'Yearly';
    }
  }
}

/// Filter options for the bills list.
///
/// [notLinked]: bills without a budget, so nothing is set aside for them.
enum BillFilter { all, upcoming, dueToday, overdue, paid, recurring, notLinked }

extension BillFilterLabel on BillFilter {
  String get label {
    switch (this) {
      case BillFilter.all:
        return 'All';
      case BillFilter.upcoming:
        return 'Upcoming';
      case BillFilter.dueToday:
        return 'Due Today';
      case BillFilter.overdue:
        return 'Overdue';
      case BillFilter.paid:
        return 'Paid';
      case BillFilter.recurring:
        return 'Recurring';
      case BillFilter.notLinked:
        return 'Not linked';
    }
  }
}
