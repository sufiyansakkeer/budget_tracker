import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:monivo/core/database/app_database.dart';
import 'package:monivo/core/domain/services/database_integrity_service.dart';

import '../../../helpers/in_memory_database.dart';

void main() {
  late AppDatabase database;
  late DatabaseIntegrityService service;

  /// Seeds the 'food' category so expense references to it are valid.
  /// The database already seeds the defaults, so this is a no-op guard.
  Future<void> seedFoodCategory() async {
    await database
        .into(database.categories)
        .insert(
          CategoriesCompanion.insert(
            id: 'food',
            name: 'Food',
            icon: 'restaurant',
            colorHex: '#FF6B6B',
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  setUp(() async {
    database = await createInMemoryDatabase();
    // The integrity service exists to find corruption in databases written
    // before foreign keys were enforced (schema < v5). Turn enforcement off
    // for this connection so the fixtures below can create that corruption.
    await database.customStatement('PRAGMA foreign_keys = OFF');
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

    test(
      'detects orphaned expenses (references non-existent budget)',
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

        final orphanIssues = result.issues
            .where((i) => i.table == 'expenses')
            .toList();
        expect(orphanIssues.length, 1);
        expect(orphanIssues.first.entityId, 'exp-orphan');
        expect(orphanIssues.first.description, contains('budget'));
      },
    );

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
            (i) => i.table == 'expenses' && i.description.contains('category'),
          )
          .toList();
      expect(catIssues.length, 1);
      expect(catIssues.first.entityId, 'exp-bad-cat');
    });

    test(
      'detects budget with invalid date range (startDate > endDate)',
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
            .where(
              (i) => i.table == 'budgets' && i.description.contains('date'),
            )
            .toList();
        expect(dateIssues.length, 1);
        expect(dateIssues.first.entityId, 'budget-bad-dates');
      },
    );

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

    group('safe-to-spend links (schema v8)', () {
      Future<void> insertBudget(
        String id, {
        String currency = 'OMR',
        double? reserved,
        double? savings,
      }) async {
        await database
            .into(database.budgets)
            .insert(
              BudgetsCompanion.insert(
                id: id,
                name: 'Budget $id',
                monthlyAmount: 500,
                remainingAmount: 500,
                currency: currency,
                startDate: DateTime(2026, 8, 1),
                endDate: DateTime(2026, 8, 31),
                reservedAmount: Value(reserved),
                savingsTarget: Value(savings),
              ),
            );
      }

      Future<void> insertBill(
        String id, {
        String? budgetId,
        String currency = 'OMR',
        bool isPaid = false,
        bool isRecurring = false,
        String recurrenceType = 'none',
      }) async {
        await database
            .into(database.bills)
            .insert(
              BillsCompanion.insert(
                id: id,
                title: 'Bill $id',
                amount: 50,
                currency: currency,
                category: 'utilities',
                dueDate: DateTime(2026, 8, 20),
                budgetId: Value(budgetId),
                isPaid: Value(isPaid),
                isRecurring: Value(isRecurring),
                recurrenceType: Value(recurrenceType),
              ),
            );
      }

      Future<void> insertBillExpense(String id, String billId) async {
        await seedFoodCategory();
        await database
            .into(database.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: id,
                budgetId: 'b1',
                amount: 50,
                categoryId: 'food',
                date: DateTime(2026, 8, 20),
                billId: Value(billId),
              ),
            );
      }

      List<IntegrityIssue> issuesFor(IntegrityCheckResult r, String id) =>
          r.issues.where((i) => i.entityId == id).toList();

      test('valid links, unset and zero set-asides pass', () async {
        await insertBudget('b1');
        await insertBudget('b2', reserved: 0, savings: 25.5);
        await insertBill('bill-linked', budgetId: 'b1');
        await insertBill('bill-free');
        await insertBill('bill-paid', budgetId: 'b1', isPaid: true);
        await insertBillExpense('e1', 'bill-paid');

        final result = await service.runFullCheck();
        expect(result.issues, isEmpty);
      });

      test('detects a bill linked to a non-existent budget', () async {
        await insertBill('bill-orphan', budgetId: 'gone');

        final issues = issuesFor(await service.runFullCheck(), 'bill-orphan');
        expect(issues, hasLength(1));
        expect(issues.single.table, 'bills');
        expect(issues.single.description, contains('gone'));
      });

      test('detects a negative reserve or savings goal', () async {
        await insertBudget('b-reserve', reserved: -1);
        await insertBudget('b-savings', savings: -0.5);

        final result = await service.runFullCheck();
        expect(issuesFor(result, 'b-reserve'), hasLength(1));
        expect(issuesFor(result, 'b-savings'), hasLength(1));
        expect(
          issuesFor(result, 'b-reserve').single.description,
          contains('set-aside'),
        );
      });

      test('detects a linked bill in another currency', () async {
        await insertBudget('b1');
        await insertBill('bill-usd', budgetId: 'b1', currency: 'USD');

        final issues = issuesFor(await service.runFullCheck(), 'bill-usd');
        expect(issues, hasLength(1));
        expect(issues.single.description, contains('USD'));
        expect(issues.single.description, contains('OMR'));
      });

      test('detects an unpaid one-time bill with a payment expense', () async {
        await insertBudget('b1');
        await insertBill('bill-once', budgetId: 'b1');
        await insertBillExpense('e1', 'bill-once');

        final issues = issuesFor(await service.runFullCheck(), 'bill-once');
        expect(issues, hasLength(1));
        expect(issues.single.description, contains('payment expense'));
      });

      test(
        'an unpaid recurring bill with payment expenses is not flagged',
        () async {
          await insertBudget('b1');
          await insertBill(
            'bill-rent',
            budgetId: 'b1',
            isRecurring: true,
            recurrenceType: 'monthly',
          );
          await insertBillExpense('e1', 'bill-rent');

          expect((await service.runFullCheck()).issues, isEmpty);
        },
      );

      test('a paid recurring bill edited into a one-time bill is not flagged '
          '(review: its earlier payment expense is valid history)', () async {
        await insertBudget('b1');
        await seedFoodCategory();
        // The bill as it is now: edited into a one-time bill (the last
        // instalment), unpaid.
        await insertBill('bill-last', budgetId: 'b1');
        // Paying the monthly occurrence wrote a payment record and an
        // expense with the same created_at; the bill advanced, unpaid.
        final paidAt = DateTime(2026, 8, 5, 9, 30);
        await database
            .into(database.billPayments)
            .insert(
              BillPaymentsCompanion.insert(
                id: 'p1',
                billId: 'bill-last',
                amount: 50,
                currency: 'OMR',
                paidDate: paidAt,
                createdAt: Value(paidAt),
              ),
            );
        await database
            .into(database.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: 'e1',
                budgetId: 'b1',
                amount: 50,
                categoryId: 'food',
                date: DateTime(2026, 8, 5),
                createdAt: Value(paidAt),
                billId: const Value('bill-last'),
              ),
            );

        expect(issuesFor(await service.runFullCheck(), 'bill-last'), isEmpty);
      });

      test('a dangling expenses.bill_id is allowed by design', () async {
        await insertBudget('b1');
        await insertBillExpense('e1', 'deleted-bill');

        expect((await service.runFullCheck()).issues, isEmpty);
      });
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
