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

  /// Material icon name for the category.
  String get iconName {
    switch (this) {
      case BillCategory.rent:
        return 'home';
      case BillCategory.utilities:
        return 'bolt';
      case BillCategory.electricity:
        return 'electric_bolt';
      case BillCategory.water:
        return 'water_drop';
      case BillCategory.internet:
        return 'wifi';
      case BillCategory.phone:
        return 'phone';
      case BillCategory.emi:
        return 'payments';
      case BillCategory.insurance:
        return 'shield';
      case BillCategory.subscription:
        return 'subscriptions';
      case BillCategory.education:
        return 'school';
      case BillCategory.healthcare:
        return 'local_hospital';
      case BillCategory.government:
        return 'account_balance';
      case BillCategory.creditCard:
        return 'credit_card';
      case BillCategory.other:
        return 'receipt_long';
    }
  }

  /// Hex color string for the category.
  String get colorHex {
    switch (this) {
      case BillCategory.rent:
        return '#48DBFB';
      case BillCategory.utilities:
        return '#FF9F43';
      case BillCategory.electricity:
        return '#FECA57';
      case BillCategory.water:
        return '#54A0FF';
      case BillCategory.internet:
        return '#5F27CD';
      case BillCategory.phone:
        return '#1DD1A1';
      case BillCategory.emi:
        return '#10AC84';
      case BillCategory.insurance:
        return '#EE5253';
      case BillCategory.subscription:
        return '#FF6B6B';
      case BillCategory.education:
        return '#00D2D3';
      case BillCategory.healthcare:
        return '#FF9FF3';
      case BillCategory.government:
        return '#8395A7';
      case BillCategory.creditCard:
        return '#D65C62';
      case BillCategory.other:
        return '#818B9B';
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
enum BillFilter { all, upcoming, dueToday, overdue, paid, recurring }

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
    }
  }
}
