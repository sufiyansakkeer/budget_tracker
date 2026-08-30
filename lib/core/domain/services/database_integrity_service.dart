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

  /// Checks for expenses that reference non-existent budgets.
  Future<List<IntegrityIssue>> _checkOrphanedExpenses() async {
    final issues = <IntegrityIssue>[];

    final expenses = await (_database.select(_database.expenses)).get();
    final budgetIds = (await (_database.select(
      _database.budgets,
    )).get()).map((b) => b.id).toSet();

    for (final expense in expenses) {
      if (!budgetIds.contains(expense.budgetId)) {
        issues.add(
          IntegrityIssue(
            table: 'expenses',
            description:
                'Expense references non-existent budget '
                '${expense.budgetId}',
            entityId: expense.id,
          ),
        );
      }
    }

    return issues;
  }

  /// Checks for expenses that reference non-existent categories.
  Future<List<IntegrityIssue>> _checkInvalidBudgetReferences() async {
    final issues = <IntegrityIssue>[];

    final expenses = await (_database.select(_database.expenses)).get();
    final categoryIds = (await (_database.select(
      _database.categories,
    )).get()).map((c) => c.id).toSet();

    for (final expense in expenses) {
      if (!categoryIds.contains(expense.categoryId)) {
        issues.add(
          IntegrityIssue(
            table: 'expenses',
            description:
                'Expense references non-existent category '
                '${expense.categoryId}',
            entityId: expense.id,
          ),
        );
      }
    }

    return issues;
  }

  /// Checks for budgets with invalid date ranges (startDate > endDate).
  Future<List<IntegrityIssue>> _checkBudgetDateRanges() async {
    final issues = <IntegrityIssue>[];

    final budgets = await (_database.select(_database.budgets)).get();

    for (final budget in budgets) {
      if (budget.startDate.isAfter(budget.endDate)) {
        issues.add(
          IntegrityIssue(
            table: 'budgets',
            description:
                'Budget has start date after end date '
                '(${budget.startDate} > ${budget.endDate})',
            entityId: budget.id,
          ),
        );
      }
    }

    return issues;
  }

  /// Checks for expenses, budgets, and bills with invalid amounts
  /// (NaN, infinity, zero, or negative).
  Future<List<IntegrityIssue>> _checkInvalidAmounts() async {
    final issues = <IntegrityIssue>[];

    // Check expenses
    final expenses = await (_database.select(_database.expenses)).get();
    for (final expense in expenses) {
      if (!expense.amount.isFinite || expense.amount <= 0) {
        issues.add(
          IntegrityIssue(
            table: 'expenses',
            description: 'Expense has invalid amount: ${expense.amount}',
            entityId: expense.id,
          ),
        );
      }
    }

    // Check budgets
    final budgets = await (_database.select(_database.budgets)).get();
    for (final budget in budgets) {
      if (!budget.monthlyAmount.isFinite || budget.monthlyAmount < 0) {
        issues.add(
          IntegrityIssue(
            table: 'budgets',
            description:
                'Budget has invalid monthlyAmount: '
                '${budget.monthlyAmount}',
            entityId: budget.id,
          ),
        );
      }
    }

    // Check bills
    final bills = await (_database.select(_database.bills)).get();
    for (final bill in bills) {
      if (!bill.amount.isFinite || bill.amount <= 0) {
        issues.add(
          IntegrityIssue(
            table: 'bills',
            description: 'Bill has invalid amount: ${bill.amount}',
            entityId: bill.id,
          ),
        );
      }
    }

    // Check savings goals
    final goals = await (_database.select(_database.savingsGoals)).get();
    for (final goal in goals) {
      if (!goal.targetAmount.isFinite || goal.targetAmount <= 0) {
        issues.add(
          IntegrityIssue(
            table: 'savingsGoals',
            description:
                'Savings goal has invalid targetAmount: '
                '${goal.targetAmount}',
            entityId: goal.id,
          ),
        );
      }
      if (!goal.currentAmount.isFinite || goal.currentAmount < 0) {
        issues.add(
          IntegrityIssue(
            table: 'savingsGoals',
            description:
                'Savings goal has invalid currentAmount: '
                '${goal.currentAmount}',
            entityId: goal.id,
          ),
        );
      }
    }

    return issues;
  }

  /// Checks for bill payments that reference non-existent bills.
  Future<List<IntegrityIssue>> _checkOrphanedBillPayments() async {
    final issues = <IntegrityIssue>[];

    final payments = await (_database.select(_database.billPayments)).get();
    final billIds = (await (_database.select(
      _database.bills,
    )).get()).map((b) => b.id).toSet();

    for (final payment in payments) {
      if (!billIds.contains(payment.billId)) {
        issues.add(
          IntegrityIssue(
            table: 'billPayments',
            description:
                'Bill payment references non-existent bill '
                '${payment.billId}',
            entityId: payment.id,
          ),
        );
      }
    }

    return issues;
  }

  /// Checks for recurring expenses that reference non-existent categories.
  Future<List<IntegrityIssue>>
  _checkOrphanedRecurringExpenseCategories() async {
    final issues = <IntegrityIssue>[];

    final recurring = await (_database.select(
      _database.recurringExpenses,
    )).get();
    final categoryIds = (await (_database.select(
      _database.categories,
    )).get()).map((c) => c.id).toSet();

    for (final rec in recurring) {
      if (!categoryIds.contains(rec.categoryId)) {
        issues.add(
          IntegrityIssue(
            table: 'recurringExpenses',
            description:
                'Recurring expense references non-existent category '
                '${rec.categoryId}',
            entityId: rec.id,
          ),
        );
      }
    }

    return issues;
  }
}
