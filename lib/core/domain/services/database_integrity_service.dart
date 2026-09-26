import 'dart:developer' as developer;

import '../../database/app_database.dart';

/// Represents a single integrity issue found during a check.
class IntegrityIssue {
  final String table;
  final String description;
  final String entityId;

  const IntegrityIssue({
    required this.table,
    required this.description,
    required this.entityId,
  });

  @override
  String toString() => '[$table] $description (id: $entityId)';
}

/// Result of a comprehensive integrity check.
class IntegrityCheckResult {
  final bool passed;
  final List<IntegrityIssue> issues;
  final DateTime checkedAt;

  const IntegrityCheckResult({
    required this.passed,
    required this.issues,
    required this.checkedAt,
  });

  bool get hasIssues => issues.isNotEmpty;
}

/// Service that performs comprehensive data integrity checks on the local
/// database. It detects orphaned records, invalid references, invalid date
/// ranges, invalid amounts, and other consistency issues.
///
/// This service follows the existing layered architecture and lives in the
/// core domain layer since it operates across multiple feature domains.
class DatabaseIntegrityService {
  final AppDatabase _database;

  DatabaseIntegrityService({required AppDatabase database})
    : _database = database;

  /// Runs all integrity checks and returns a comprehensive result.
  Future<IntegrityCheckResult> runFullCheck() async {
    developer.log('[Database] Starting integrity check', name: 'Database');
    final issues = <IntegrityIssue>[];

    issues.addAll(await _checkOrphanedExpenses());
    issues.addAll(await _checkInvalidBudgetReferences());
    issues.addAll(await _checkBudgetDateRanges());
    issues.addAll(await _checkInvalidAmounts());
    issues.addAll(await _checkOrphanedBillPayments());
    issues.addAll(await _checkOrphanedRecurringExpenseCategories());

    final result = IntegrityCheckResult(
      passed: issues.isEmpty,
      issues: issues,
      checkedAt: DateTime.now(),
    );

    if (issues.isEmpty) {
      developer.log('[Database] Integrity check: all passed', name: 'Database');
    } else {
      developer.log(
        '[Database] Integrity check: ${issues.length} issues found',
        name: 'Database',
      );
    }

    return result;
  }

  /// Runs [sql] and turns each returned row into an issue.
  ///
  /// Every check is an anti-join or a predicate, so SQLite returns only the
  /// offending rows — usually none. Loading whole tables to fold them in Dart
  /// froze the UI isolate on a large database.
  Future<List<IntegrityIssue>> _query(
    String sql, {
    required String table,
    required String Function(Map<String, Object?> row) describe,
    String idColumn = 'id',
  }) async {
    final rows = await _database.customSelect(sql).get();
    return [
      for (final row in rows)
        IntegrityIssue(
          table: table,
          description: describe(row.data),
          entityId: row.data[idColumn]?.toString() ?? 'unknown',
        ),
    ];
  }

  /// Checks for expenses that reference non-existent budgets.
  Future<List<IntegrityIssue>> _checkOrphanedExpenses() {
    return _query(
      'SELECT id, budget_id FROM expenses '
      'WHERE budget_id NOT IN (SELECT id FROM budgets)',
      table: 'expenses',
      describe: (row) =>
          'Expense references non-existent budget ${row['budget_id']}',
    );
  }

  /// Checks for expenses that reference non-existent categories.
  Future<List<IntegrityIssue>> _checkInvalidBudgetReferences() {
    return _query(
      'SELECT id, category_id FROM expenses '
      'WHERE category_id NOT IN (SELECT id FROM categories)',
      table: 'expenses',
      describe: (row) =>
          'Expense references non-existent category ${row['category_id']}',
    );
  }

  /// Checks for budgets with invalid date ranges (startDate > endDate).
  Future<List<IntegrityIssue>> _checkBudgetDateRanges() {
    return _query(
      'SELECT id, start_date, end_date FROM budgets '
      'WHERE start_date > end_date',
      table: 'budgets',
      describe: (row) =>
          'Budget has start date after end date '
          '(${_asDate(row['start_date'])} > ${_asDate(row['end_date'])})',
    );
  }

  /// Drift stores DateTime columns as unix seconds.
  static String _asDate(Object? value) {
    final seconds = value is int ? value : int.tryParse('$value');
    if (seconds == null) return '$value';
    return DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
    ).toIso8601String();
  }

  /// Checks for expenses, budgets, and bills with invalid amounts
  /// (NaN, infinity, zero, or negative).
  ///
  /// `NOT (amount > 0)` also catches NaN, which compares false to everything.
  Future<List<IntegrityIssue>> _checkInvalidAmounts() async {
    final results = await Future.wait([
      _query(
        'SELECT id, amount FROM expenses WHERE NOT (amount > 0)',
        table: 'expenses',
        describe: (row) => 'Expense has invalid amount: ${row['amount']}',
      ),
      _query(
        'SELECT id, monthly_amount FROM budgets '
        'WHERE NOT (monthly_amount >= 0)',
        table: 'budgets',
        describe: (row) =>
            'Budget has invalid monthlyAmount: ${row['monthly_amount']}',
      ),
      _query(
        'SELECT id, amount FROM bills WHERE NOT (amount > 0)',
        table: 'bills',
        describe: (row) => 'Bill has invalid amount: ${row['amount']}',
      ),
    ]);
    return results.expand((issues) => issues).toList();
  }

  /// Checks for bill payments that reference non-existent bills.
  Future<List<IntegrityIssue>> _checkOrphanedBillPayments() {
    return _query(
      'SELECT id, bill_id FROM bill_payments '
      'WHERE bill_id NOT IN (SELECT id FROM bills)',
      table: 'billPayments',
      describe: (row) =>
          'Bill payment references non-existent bill ${row['bill_id']}',
    );
  }

  /// Checks for recurring expenses that reference non-existent categories.
  Future<List<IntegrityIssue>> _checkOrphanedRecurringExpenseCategories() {
    return _query(
      'SELECT id, category_id FROM recurring_expenses '
      'WHERE category_id NOT IN (SELECT id FROM categories)',
      table: 'recurringExpenses',
      describe: (row) =>
          'Recurring expense references non-existent category '
          '${row['category_id']}',
    );
  }
}
