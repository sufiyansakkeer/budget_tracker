import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/expense_entity.dart';

/// Maps between the Drift [Expense] row and the domain [ExpenseEntity].
class ExpenseModel {
  ExpenseModel._();

  /// Tags are stored as a JSON string in the database.
  static String? encodeTags(List<String> tags) {
    if (tags.isEmpty) return null;
    return jsonEncode(tags);
  }

  static List<String> decodeTags(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  static ExpenseEntity toEntity(Expense row) {
    return ExpenseEntity(
      id: row.id,
      amount: row.amount,
      categoryId: row.categoryId,
      note: row.note,
      date: row.date,
      time: row.time,
      receiptImagePath: row.receiptImagePath,
      tags: decodeTags(row.tags),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static ExpensesCompanion toCompanion(ExpenseEntity entity) {
    return ExpensesCompanion.insert(
      id: entity.id,
      amount: entity.amount,
      categoryId: entity.categoryId,
      note: Value(entity.note),
      date: entity.date,
      time: Value(entity.time),
      receiptImagePath: Value(entity.receiptImagePath),
      tags: Value(encodeTags(entity.tags)),
      createdAt: Value(entity.createdAt),
      updatedAt: Value(entity.updatedAt),
    );
  }
}
