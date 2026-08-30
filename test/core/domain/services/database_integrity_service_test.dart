import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/core/domain/services/database_integrity_service.dart';

import '../../../helpers/in_memory_database.dart';

void main() {
  late AppDatabase database;
  late DatabaseIntegrityService service;

  /// Seeds the 'food' category so expense references to it are valid.
  Future<void> seedFoodCategory() async {
    await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            id: 'food',
            name: 'Food',
            icon: 'restaurant',
            colorHex: '#FF6B6B',
          ),
        );
  }

  setUp(() async {
    database = await createInMemoryDatabase();
    service = DatabaseIntegrityService(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  group('DatabaseIntegrityService', () {
    test('passes on empty database with no data', () async {
      final result = await service.runFullCheck();
      expect(result.passed, isTrue);
      expect(result.hasIssues, isFalse);
      expect(result.issues, isEmpty);
    });

    test('detects orphaned expenses (references non-existent budget)',
        () async {
      await seedFoodCategory();

      // Insert an expense referencing a non-existent budget.
      await database
          .into(database.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: 'exp-orphan',
              budgetId: 'nonexistent-budget',
              amount: 100,
              categoryId: 'food',
              date: DateTime(2026, 8, 1),
            ),
          );

      final result = await service.runFullCheck();
      expect(result.passed, isFalse);
      expect(result.hasIssues, isTrue);

      final orphanIssues =
          result.issues.where((i) => i.table == 'expenses').toList();
      expect(orphanIssues.length, 1);
      expect(orphanIssues.first.entityId, 'exp-orphan');
      expect(orphanIssues.first.description, contains('budget'));
    });

    test('detects expenses referencing non-existent categories', () async {
      // First insert a valid budget so the expense's budget reference is OK.
      await database
          .into(database.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: 'budget-1',
              name: 'Test Budget',
              monthlyAmount: 10000,
              remainingAmount: 10000,
              currency: 'INR',
              startDate: DateTime(2026, 8, 1),
              endDate: DateTime(2026, 8, 31),
            ),
          );

      // Insert an expense referencing a non-existent category.
      await database
          .into(database.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: 'exp-bad-cat',
              budgetId: 'budget-1',
              amount: 100,
              categoryId: 'nonexistent-category',
              date: DateTime(2026, 8, 1),
            ),
          );

      final result = await service.runFullCheck();
      expect(result.passed, isFalse);

      final catIssues = result.issues
          .where(
            (i) =>
                i.table == 'expenses' &&
                i.description.contains('category'),
          )
          .toList();
      expect(catIssues.length, 1);
      expect(catIssues.first.entityId, 'exp-bad-cat');
    });

    test('detects budget with invalid date range (startDate > endDate)',
        () async {
      await database
          .into(database.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: 'budget-bad-dates',
              name: 'Bad Dates Budget',
              monthlyAmount: 10000,
              remainingAmount: 10000,
              currency: 'INR',
              startDate: DateTime(2026, 8, 31),
              endDate: DateTime(2026, 8, 1), // End before start!
            ),
          );

      final result = await service.runFullCheck();
      expect(result.passed, isFalse);

      final dateIssues = result.issues
          .where((i) => i.table == 'budgets' && i.description.contains('date'))
          .toList();
      expect(dateIssues.length, 1);
      expect(dateIssues.first.entityId, 'budget-bad-dates');
    });

    test('detects expense with invalid amount (zero)', () async {
      // First insert a valid budget.
      await database
          .into(database.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: 'budget-1',
              name: 'Test',
              monthlyAmount: 10000,
              remainingAmount: 10000,
              currency: 'INR',
              startDate: DateTime(2026, 8, 1),
              endDate: DateTime(2026, 8, 31),
            ),
          );

      await seedFoodCategory();

      // Insert an expense with zero amount (invalid).
      await database
          .into(database.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: 'exp-zero',
              budgetId: 'budget-1',
              amount: 0, // Invalid: zero
              categoryId: 'food',
              date: DateTime(2026, 8, 1),
            ),
          );

      final result = await service.runFullCheck();
      expect(result.passed, isFalse);

      final amountIssues = result.issues
          .where((i) => i.description.contains('invalid amount'))
          .toList();
      expect(amountIssues.length, greaterThanOrEqualTo(1));
    });

    test('detects budget with negative monthlyAmount', () async {
      await database
          .into(database.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: 'budget-neg',
              name: 'Negative Budget',
              monthlyAmount: -1000, // Invalid
              remainingAmount: -1000,
              currency: 'INR',
              startDate: DateTime(2026, 8, 1),
              endDate: DateTime(2026, 8, 31),
            ),
          );

      final result = await service.runFullCheck();
      expect(result.passed, isFalse);

      final budgetAmountIssues = result.issues
          .where(
            (i) =>
                i.table == 'budgets' &&
                i.description.contains('invalid monthlyAmount'),
          )
          .toList();
      expect(budgetAmountIssues.length, 1);
    });

    test('detects orphaned bill payments', () async {
      // Insert a payment referencing a non-existent bill.
      await database
          .into(database.billPayments)
          .insert(
            BillPaymentsCompanion.insert(
              id: 'payment-orphan',
              billId: 'nonexistent-bill',
              amount: 500,
              currency: 'INR',
              paidDate: DateTime(2026, 8, 1),
            ),
          );

      final result = await service.runFullCheck();
      expect(result.passed, isFalse);

      final orphanPayments = result.issues
          .where((i) => i.table == 'billPayments')
          .toList();
      expect(orphanPayments.length, 1);
      expect(orphanPayments.first.entityId, 'payment-orphan');
    });

    test('detects orphaned recurring expense categories', () async {
      // Insert a recurring expense referencing a non-existent category.
      await database
          .into(database.recurringExpenses)
          .insert(
            RecurringExpensesCompanion.insert(
              id: 'rec-orphan',
              title: 'Test Recurring',
              amount: 500,
              categoryId: 'nonexistent-cat',
              frequency: 'monthly',
              nextDueDate: DateTime(2026, 9, 1),
            ),
          );

      final result = await service.runFullCheck();
      expect(result.passed, isFalse);

      final orphanRecurring = result.issues
          .where((i) => i.table == 'recurringExpenses')
          .toList();
      expect(orphanRecurring.length, 1);
      expect(orphanRecurring.first.entityId, 'rec-orphan');
    });

    test('passes with valid data across all tables', () async {
      await seedFoodCategory();

      // Insert valid budget.
      await database
          .into(database.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: 'budget-1',
              name: 'Valid Budget',
              monthlyAmount: 10000,
              remainingAmount: 5000,
              currency: 'INR',
              startDate: DateTime(2026, 8, 1),
              endDate: DateTime(2026, 8, 31),
            ),
          );

      // Insert valid expense.
      await database
          .into(database.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: 'exp-1',
              budgetId: 'budget-1',
              amount: 500,
              categoryId: 'food',
              date: DateTime(2026, 8, 5),
            ),
          );

      // Insert valid bill.
      await database
          .into(database.bills)
          .insert(
            BillsCompanion.insert(
              id: 'bill-1',
              title: 'Electricity',
              amount: 1500,
              currency: 'INR',
              category: 'utilities',
              dueDate: DateTime(2026, 8, 15),
            ),
          );

      // Insert valid bill payment.
      await database
          .into(database.billPayments)
          .insert(
            BillPaymentsCompanion.insert(
              id: 'payment-1',
              billId: 'bill-1',
              amount: 1500,
              currency: 'INR',
              paidDate: DateTime(2026, 8, 14),
            ),
          );

      final result = await service.runFullCheck();
      expect(result.passed, isTrue);
      expect(result.hasIssues, isFalse);
    });

    test('reports multiple issues at once', () async {
      // Multiple issues: orphaned expense + bad budget dates + bad bill payment
      await database
          .into(database.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: 'exp-orphan-1',
              budgetId: 'nonexistent',
              amount: 100,
              categoryId: 'food',
              date: DateTime(2026, 8, 1),
            ),
          );

      await database
          .into(database.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: 'budget-bad',
              name: 'Bad',
              monthlyAmount: 10000,
              remainingAmount: 10000,
              currency: 'INR',
              startDate: DateTime(2026, 8, 31),
              endDate: DateTime(2026, 8, 1),
            ),
          );

      await database
          .into(database.billPayments)
          .insert(
            BillPaymentsCompanion.insert(
              id: 'pay-orphan',
              billId: 'nonexistent-bill',
              amount: 500,
              currency: 'INR',
              paidDate: DateTime(2026, 8, 1),
            ),
          );

      final result = await service.runFullCheck();
      expect(result.passed, isFalse);
      // At least 3: orphaned expense, bad date range, orphaned payment,
      // and possibly orphaned category for 'food'
      expect(result.issues.length, greaterThanOrEqualTo(3));
    });

    test('IntegrityCheckResult includes checkedAt timestamp', () async {
      final before = DateTime.now();
      final result = await service.runFullCheck();
      final after = DateTime.now();

      expect(
        result.checkedAt.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        result.checkedAt.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('IntegrityIssue toString formats correctly', () {
      const issue = IntegrityIssue(
        table: 'expenses',
        description: 'Orphaned expense',
        entityId: 'exp-1',
      );

      expect(issue.toString(), '[expenses] Orphaned expense (id: exp-1)');
    });
  });
}
