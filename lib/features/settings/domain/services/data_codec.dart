import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';

/// How each table's rows are written to, and read back from, Monivo's JSON
/// files. Backups, data exports and imports share this one mapping, so a
/// column added to a table is added to every file.
///
/// Reading is lenient where older files lack a key: a missing optional
/// field is left absent, so an insert takes the column default and an
/// upsert keeps the stored value.
abstract final class DataCodec {
  static Map<String, Object?> encodeBudget(Budget b) => {
    'id': b.id,
    'name': b.name,
    'monthlyAmount': b.monthlyAmount,
    'remainingAmount': b.remainingAmount,
    'currency': b.currency,
    'startDate': b.startDate.toIso8601String(),
    'endDate': b.endDate.toIso8601String(),
    'isArchived': b.isArchived,
    'color': b.color,
    'icon': b.icon,
    'notes': b.notes,
    'createdAt': b.createdAt.toIso8601String(),
    'updatedAt': b.updatedAt.toIso8601String(),
    'reservedAmount': b.reservedAmount,
    'savingsTarget': b.savingsTarget,
  };

  static BudgetsCompanion decodeBudget(Map map) => BudgetsCompanion.insert(
    id: map['id'] as String,
    name: (map['name'] as String?) ?? 'Personal Budget',
    monthlyAmount: (map['monthlyAmount'] as num).toDouble(),
    remainingAmount: (map['remainingAmount'] as num).toDouble(),
    currency: map['currency'] as String,
    startDate: DateTime.parse(map['startDate'] as String),
    endDate: DateTime.parse(map['endDate'] as String),
    isArchived: Value((map['isArchived'] as bool?) ?? false),
    color: Value(map['color'] as String?),
    icon: Value(map['icon'] as String?),
    notes: Value(map['notes'] as String?),
    createdAt: Value(DateTime.parse(map['createdAt'] as String)),
    updatedAt: Value(DateTime.parse(map['updatedAt'] as String)),
    reservedAmount: _optionalDouble(map, 'reservedAmount'),
    savingsTarget: _optionalDouble(map, 'savingsTarget'),
  );

  static Map<String, Object?> encodeCategory(Category c) => {
    'id': c.id,
    'name': c.name,
    'icon': c.icon,
    'colorHex': c.colorHex,
    'isSystem': c.isSystem,
    'isArchived': c.isArchived,
  };

  static CategoriesCompanion decodeCategory(Map map) =>
      CategoriesCompanion.insert(
        id: map['id'] as String,
        name: map['name'] as String,
        icon: map['icon'] as String,
        colorHex: map['colorHex'] as String,
        isSystem: Value((map['isSystem'] as bool?) ?? true),
        // Files from before archiving lack the key: an import keeps the
        // category's stored state.
        isArchived: map.containsKey('isArchived')
            ? Value((map['isArchived'] as bool?) ?? false)
            : const Value.absent(),
      );

  /// Tags go out as stored: the JSON string, or null.
  static Map<String, Object?> encodeExpense(Expense e) => {
    'id': e.id,
    'budgetId': e.budgetId,
    'amount': e.amount,
    'categoryId': e.categoryId,
    'note': e.note,
    'date': e.date.toIso8601String(),
    'time': e.time.toIso8601String(),
    'receiptImagePath': e.receiptImagePath,
    'tags': e.tags,
    'createdAt': e.createdAt.toIso8601String(),
    'updatedAt': e.updatedAt.toIso8601String(),
    'billId': e.billId,
  };

  /// [budgetId] is the budget the expense goes to: the caller decides what
  /// a record without one belongs to.
  static ExpensesCompanion decodeExpense(Map map, {required String budgetId}) =>
      ExpensesCompanion.insert(
        id: (map['id'] as String?) ?? const Uuid().v4(),
        budgetId: budgetId,
        amount: (map['amount'] as num).toDouble(),
        categoryId: map['categoryId'] as String,
        note: Value(map['note'] as String?),
        date: DateTime.parse(map['date'] as String),
        time: Value(DateTime.parse(map['time'] as String)),
        receiptImagePath: Value(map['receiptImagePath'] as String?),
        tags: Value(normalizeTags(map['tags'])),
        createdAt: Value(DateTime.parse(map['createdAt'] as String)),
        updatedAt: Value(DateTime.parse(map['updatedAt'] as String)),
        // No foreign key: kept as-is even if the bill is absent.
        billId: map.containsKey('billId')
            ? Value(map['billId'] as String?)
            : const Value.absent(),
      );

  static Map<String, Object?> encodeRecurringExpense(RecurringExpense r) => {
    'id': r.id,
    'title': r.title,
    'amount': r.amount,
    'categoryId': r.categoryId,
    'frequency': r.frequency,
    'nextDueDate': r.nextDueDate.toIso8601String(),
    'isActive': r.isActive,
  };

  static RecurringExpensesCompanion decodeRecurringExpense(Map map) =>
      RecurringExpensesCompanion.insert(
        id: map['id'] as String,
        title: map['title'] as String,
        amount: (map['amount'] as num).toDouble(),
        categoryId: map['categoryId'] as String,
        frequency: map['frequency'] as String,
        nextDueDate: DateTime.parse(map['nextDueDate'] as String),
        isActive: Value((map['isActive'] as bool?) ?? true),
      );

  static Map<String, Object?> encodeSavingsGoal(SavingsGoal g) => {
    'id': g.id,
    'title': g.title,
    'targetAmount': g.targetAmount,
    'currentAmount': g.currentAmount,
    'targetDate': g.targetDate.toIso8601String(),
  };

  static SavingsGoalsCompanion decodeSavingsGoal(Map map) =>
      SavingsGoalsCompanion.insert(
        id: map['id'] as String,
        title: map['title'] as String,
        targetAmount: (map['targetAmount'] as num).toDouble(),
        currentAmount: Value((map['currentAmount'] as num?)?.toDouble() ?? 0),
        targetDate: DateTime.parse(map['targetDate'] as String),
      );

  static Map<String, Object?> encodeBill(Bill b) => {
    'id': b.id,
    'title': b.title,
    'note': b.note,
    'amount': b.amount,
    'currency': b.currency,
    'category': b.category,
    'dueDate': b.dueDate.toIso8601String(),
    'dueTime': b.dueTime?.toIso8601String(),
    'isRecurring': b.isRecurring,
    'recurrenceType': b.recurrenceType,
    'recurrenceInterval': b.recurrenceInterval,
    'reminderEnabled': b.reminderEnabled,
    'reminderOffsetDays': b.reminderOffsetDays,
    'isPaid': b.isPaid,
    'paidDate': b.paidDate?.toIso8601String(),
    'createdAt': b.createdAt.toIso8601String(),
    'updatedAt': b.updatedAt.toIso8601String(),
    'budgetId': b.budgetId,
  };

  /// [budgetId] is the budget the bill links to, or null for none: the
  /// caller checks the link points at a budget the database will have.
  static BillsCompanion decodeBill(Map map, {required String? budgetId}) =>
      BillsCompanion.insert(
        id: map['id'] as String,
        title: map['title'] as String,
        note: Value(map['note'] as String?),
        amount: (map['amount'] as num).toDouble(),
        currency: map['currency'] as String,
        category: map['category'] as String,
        dueDate: DateTime.parse(map['dueDate'] as String),
        dueTime: Value(_optionalDate(map['dueTime'])),
        isRecurring: Value((map['isRecurring'] as bool?) ?? false),
        recurrenceType: Value((map['recurrenceType'] as String?) ?? 'none'),
        recurrenceInterval: Value(
          (map['recurrenceInterval'] as num?)?.toInt() ?? 1,
        ),
        reminderEnabled: Value((map['reminderEnabled'] as bool?) ?? false),
        reminderOffsetDays: Value(
          (map['reminderOffsetDays'] as num?)?.toInt() ?? 1,
        ),
        isPaid: Value((map['isPaid'] as bool?) ?? false),
        paidDate: Value(_optionalDate(map['paidDate'])),
        createdAt: Value(DateTime.parse(map['createdAt'] as String)),
        updatedAt: Value(DateTime.parse(map['updatedAt'] as String)),
        budgetId: Value(budgetId),
      );

  static Map<String, Object?> encodeBillPayment(BillPayment p) => {
    'id': p.id,
    'billId': p.billId,
    'amount': p.amount,
    'currency': p.currency,
    'paidDate': p.paidDate.toIso8601String(),
    'createdAt': p.createdAt.toIso8601String(),
  };

  static BillPaymentsCompanion decodeBillPayment(Map map) =>
      BillPaymentsCompanion.insert(
        id: map['id'] as String,
        billId: map['billId'] as String,
        amount: (map['amount'] as num).toDouble(),
        currency: map['currency'] as String,
        paidDate: DateTime.parse(map['paidDate'] as String),
        createdAt: Value(DateTime.parse(map['createdAt'] as String)),
      );

  /// Tags as they are stored: a JSON list of strings, or null for none.
  ///
  /// Files carry tags in three shapes, all accepted: a JSON list (a Monivo
  /// data file), the stored JSON string itself (a Monivo export or backup,
  /// which writes the column as it is), or comma-separated text (a
  /// spreadsheet). Anything else is rejected, so a malformed file fails
  /// before writing.
  static String? normalizeTags(Object? raw) {
    if (raw == null) return null;
    List<String> clean(Iterable<Object?> items) => [
      for (final t in items)
        if (t != null && t.toString().trim().isNotEmpty) t.toString().trim(),
    ];

    final List<String> tags;
    if (raw is List) {
      tags = clean(raw);
    } else if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) return null;
      List<String>? decoded;
      if (text.startsWith('[')) {
        try {
          final value = jsonDecode(text);
          if (value is List) decoded = clean(value);
        } on FormatException {
          decoded = null;
        }
      }
      tags = decoded ?? clean(text.split(','));
    } else {
      throw FormatException('Invalid tags: $raw');
    }
    return tags.isEmpty ? null : jsonEncode(tags);
  }

  /// A nullable money field: absent when the key is missing (an insert takes
  /// the default, an upsert keeps the stored value), otherwise the value.
  static Value<double?> _optionalDouble(Map map, String key) {
    if (!map.containsKey(key)) return const Value.absent();
    return Value((map[key] as num?)?.toDouble());
  }

  static DateTime? _optionalDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}
