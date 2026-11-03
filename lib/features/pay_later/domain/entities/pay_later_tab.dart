import 'package:equatable/equatable.dart';

import 'settle_rhythm.dart';

/// What a tab is for. Presentation only (icon and grouping); no behaviour
/// depends on it.
enum PayLaterTabCategory {
  foodDining('food_dining'),
  groceries('groceries'),
  shopping('shopping'),
  personal('personal'),
  other('other');

  /// Stored value.
  final String key;

  const PayLaterTabCategory(this.key);

  /// The category stored as [key]; [other] for an unknown key.
  static PayLaterTabCategory fromKey(String key) {
    for (final category in values) {
      if (category.key == key) return category;
    }
    return other;
  }
}

/// A running account with someone who lets you pay later (a cafeteria, a
/// corner shop, a friend).
class PayLaterTab extends Equatable {
  final String id;
  final String name;
  final PayLaterTabCategory category;

  /// ISO code; fixed once the tab has purchases or payments.
  final String currency;
  final String? note;

  /// Free text: phone, person, location.
  final String? contact;

  /// Expense category preselected when adding to this tab.
  final String? defaultCategoryId;
  final SettleRhythm rhythm;
  final bool reminderEnabled;

  /// Days before the settle-up day; 0 = on the day.
  final int reminderOffsetDays;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PayLaterTab({
    required this.id,
    required this.name,
    required this.category,
    required this.currency,
    this.note,
    this.contact,
    this.defaultCategoryId,
    required this.rhythm,
    this.reminderEnabled = false,
    this.reminderOffsetDays = 0,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  PayLaterTab copyWith({
    String? id,
    String? name,
    PayLaterTabCategory? category,
    String? currency,
    String? note,
    bool clearNote = false,
    String? contact,
    bool clearContact = false,
    String? defaultCategoryId,
    bool clearDefaultCategoryId = false,
    SettleRhythm? rhythm,
    bool? reminderEnabled,
    int? reminderOffsetDays,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PayLaterTab(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      currency: currency ?? this.currency,
      note: clearNote ? null : (note ?? this.note),
      contact: clearContact ? null : (contact ?? this.contact),
      defaultCategoryId: clearDefaultCategoryId
          ? null
          : (defaultCategoryId ?? this.defaultCategoryId),
      rhythm: rhythm ?? this.rhythm,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderOffsetDays: reminderOffsetDays ?? this.reminderOffsetDays,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    category,
    currency,
    note,
    contact,
    defaultCategoryId,
    rhythm,
    reminderEnabled,
    reminderOffsetDays,
    isArchived,
    createdAt,
    updatedAt,
  ];
}
