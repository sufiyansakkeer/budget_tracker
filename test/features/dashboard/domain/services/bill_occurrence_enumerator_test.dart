import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/domain/entities/budget_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_entity.dart';
import 'package:monivo/features/bills/domain/entities/bill_enums.dart';
import 'package:monivo/features/bills/domain/entities/bill_failure.dart';
import 'package:monivo/features/bills/domain/usecases/mark_bill_paid_usecase.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/currency_excluded_summary.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/unlinked_commitment_summary.dart';
import 'package:monivo/features/dashboard/domain/services/bill_occurrence_enumerator.dart';

import '../../../../helpers/safe_to_spend_fakes.dart';

void main() {
  const enumerator = BillOccurrenceEnumerator();
  // House fixture: an August 2026 budget evaluated on Mon 10 Aug.
  final today = DateTime(2026, 8, 10);

  BudgetEntity budget({
    String id = 'aug',
    String currency = 'INR',
    DateTime? start,
    DateTime? end,
    bool archived = false,
  }) {
    final s = start ?? DateTime(2026, 8, 1);
    return BudgetEntity(
      id: id,
      name: 'Budget $id',
      monthlyAmount: 30000,
      remainingAmount: 30000,
      currency: currency,
      startDate: s,
      endDate: end ?? DateTime(2026, 8, 31),
      isArchived: archived,
      createdAt: s,
      updatedAt: s,
    );
  }

  BillEntity bill({
    String id = 'rent',
    double amount = 500,
    String currency = 'INR',
    required DateTime due,
    String? budgetId = 'aug',
    RecurrenceType recurrence = RecurrenceType.none,
    int interval = 1,
    bool isPaid = false,
  }) {
    return BillEntity(
      id: id,
      title: 'Bill $id',
      amount: amount,
      currency: currency,
      category: BillCategory.rent,
      dueDate: due,
      isRecurring: recurrence != RecurrenceType.none,
      recurrenceType: recurrence,
      recurrenceInterval: interval,
      isPaid: isPaid,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      budgetId: budgetId,
    );
  }

  List<DateTime> dueDates(Iterable<dynamic> occurrences) =>
      occurrences.map<DateTime>((o) => o.dueDate as DateTime).toList();

  group('linked occurrences', () {
    test('an unpaid one-time bill in the period is set aside once', () {
      final result = enumerator.forBudget(
        budget: budget(),
        bills: [bill(due: DateTime(2026, 8, 20), amount: 2200)],
        budgetsById: {},
        today: today,
      );

      expect(result.occurrences, hasLength(1));
      final o = result.occurrences.single;
      expect(o.billId, 'rent');
      expect(o.title, 'Bill rent');
      expect(o.amount, 2200);
      expect(o.dueDate, DateTime(2026, 8, 20));
      expect(o.isOverdue, isFalse);
      expect(result.unlinked, UnlinkedCommitmentSummary.none);
      expect(result.currencyExcluded, CurrencyExcludedSummary.none);
    });

    test('a paid bill is excluded', () {
      final result = enumerator.forBudget(
        budget: budget(),
        bills: [bill(due: DateTime(2026, 8, 20), isPaid: true)],
        budgetsById: {},
        today: today,
      );
      expect(result.occurrences, isEmpty);
      expect(result.unlinked.isEmpty, isTrue);
    });

    test('a cancelled (deleted) bill is absent: there is no cancelled state, '
        'so a deleted bill simply is not in the list', () {
      final kept = bill(id: 'phone', due: DateTime(2026, 8, 12));
      final deleted = bill(id: 'gym', due: DateTime(2026, 8, 14));

      final before = enumerator.forBudget(
        budget: budget(),
        bills: [kept, deleted],
        budgetsById: {},
        today: today,
      );
      final after = enumerator.forBudget(
        budget: budget(),
        bills: [kept],
        budgetsById: {},
        today: today,
      );

      expect(before.occurrences.map((o) => o.billId), ['phone', 'gym']);
      expect(after.occurrences.map((o) => o.billId), ['phone']);
    });

    test('weekly every 2 weeks steps 14 days, not 7', () {
      final result = enumerator.forBudget(
        budget: budget(),
        bills: [
          bill(
            due: DateTime(2026, 8, 3),
            recurrence: RecurrenceType.weekly,
            interval: 2,
          ),
        ],
        budgetsById: {},
        today: today,
      );

      expect(dueDates(result.occurrences), [
        DateTime(2026, 8, 3),
        DateTime(2026, 8, 17),
        DateTime(2026, 8, 31),
      ]);
      expect(result.occurrences.map((o) => o.isOverdue), [true, false, false]);
    });

    test('monthly every 2 months honours the interval', () {
      final dates = enumerator.dueDatesUntil(
        bill(
          due: DateTime(2026, 1, 15),
          recurrence: RecurrenceType.monthly,
          interval: 2,
        ),
        DateTime(2026, 8, 31),
      );
      expect(dates, [
        DateTime(2026, 1, 15),
        DateTime(2026, 3, 15),
        DateTime(2026, 5, 15),
        DateTime(2026, 7, 15),
      ]);
    });

    test(
      'monthly from Jan 31 equals the dates chained MarkBillPaid stores',
      () async {
        final rent = bill(
          due: DateTime(2026, 1, 31),
          recurrence: RecurrenceType.monthly,
        );
        final repository = SafeSpendFakeBillRepository([rent]);
        final markPaid = MarkBillPaidUseCase(repository: repository);

        final stored = <DateTime>[rent.dueDate];
        for (var i = 0; i < 11; i++) {
          final result = await markPaid('rent');
          expect(result, isA<BillSuccess<BillEntity>>());
          stored.add((await repository.getBillById('rent'))!.dueDate);
        }

        final enumerated = enumerator.dueDatesUntil(
          rent,
          DateTime(2026, 12, 31),
        );

        expect(enumerated, stored);
        // Clamp drift is preserved, exactly as payments store it.
        expect(enumerated.take(4), [
          DateTime(2026, 1, 31),
          DateTime(2026, 2, 28),
          DateTime(2026, 3, 28),
          DateTime(2026, 4, 28),
        ]);
      },
    );

    test(
      'a running budget carries overdue occurrences from before its start',
      () {
        final result = enumerator.forBudget(
          budget: budget(),
          bills: [
            bill(due: DateTime(2026, 7, 5), recurrence: RecurrenceType.monthly),
            bill(id: 'fee', due: DateTime(2026, 7, 28), amount: 90),
          ],
          budgetsById: {},
          today: today,
        );

        expect(dueDates(result.occurrences), [
          DateTime(2026, 7, 5),
          DateTime(2026, 8, 5),
          DateTime(2026, 7, 28),
        ]);
        expect(result.occurrences.every((o) => o.isOverdue), isTrue);
      },
    );

    test('occurrences after the period end are not set aside', () {
      final result = enumerator.forBudget(
        budget: budget(),
        bills: [bill(due: DateTime(2026, 9, 1))],
        budgetsById: {},
        today: today,
      );
      expect(result.occurrences, isEmpty);
    });

    test('a budget that has not started sets aside only its own window', () {
      final september = budget(
        id: 'sep',
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 30),
      );
      final result = enumerator.forBudget(
        budget: september,
        bills: [
          bill(
            due: DateTime(2026, 8, 5),
            budgetId: 'sep',
            recurrence: RecurrenceType.monthly,
          ),
        ],
        budgetsById: {'sep': september},
        today: today,
      );

      expect(dueDates(result.occurrences), [DateTime(2026, 9, 5)]);
      expect(result.occurrences.single.isOverdue, isFalse);
    });

    test('an ended budget sets aside only its own window', () {
      final july = budget(
        id: 'jul',
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 31),
      );
      final result = enumerator.forBudget(
        budget: july,
        bills: [
          bill(
            due: DateTime(2026, 6, 20),
            budgetId: 'jul',
            recurrence: RecurrenceType.monthly,
          ),
        ],
        budgetsById: {'jul': july},
        today: today,
      );

      expect(dueDates(result.occurrences), [DateTime(2026, 7, 20)]);
      expect(result.occurrences.single.isOverdue, isTrue);
    });

    test('a linked bill in another currency is excluded and disclosed', () {
      final result = enumerator.forBudget(
        budget: budget(),
        bills: [
          bill(
            id: 'cloud',
            currency: 'USD',
            amount: 40.1,
            due: DateTime(2026, 8, 12),
            recurrence: RecurrenceType.weekly,
          ),
          bill(id: 'rent', due: DateTime(2026, 8, 20)),
        ],
        budgetsById: {},
        today: today,
      );

      expect(result.occurrences.map((o) => o.billId), ['rent']);
      expect(result.currencyExcluded.count, 1);
      // Aug 12, 19, 26 → 3 × 40.1, summed in units (no float drift).
      expect(result.currencyExcluded.totalsByCurrency, {'USD': 120.3});
    });

    test('a non-advancing interval cannot loop forever', () {
      final dates = enumerator.dueDatesUntil(
        bill(
          due: DateTime(2026, 8, 3),
          recurrence: RecurrenceType.weekly,
          interval: 0,
        ),
        DateTime(2026, 8, 31),
      );
      expect(dates, [DateTime(2026, 8, 3)]);
    });

    test('isRecurring with recurrence "none" is a single occurrence, as '
        'MarkBillPaid treats it', () {
      final odd = bill(
        due: DateTime(2026, 8, 3),
      ).copyWith(isRecurring: true, recurrenceType: RecurrenceType.none);
      expect(enumerator.dueDatesUntil(odd, DateTime(2026, 12, 31)), [
        DateTime(2026, 8, 3),
      ]);
    });

    test('the time of day on a due date is ignored', () {
      final result = enumerator.forBudget(
        budget: budget(),
        bills: [bill(due: DateTime(2026, 8, 31, 18, 30))],
        budgetsById: {},
        today: DateTime(2026, 8, 10, 23, 59),
      );
      expect(dueDates(result.occurrences), [DateTime(2026, 8, 31)]);
    });
  });

  group('unlinked summary', () {
    test(
      'counts bills nobody sets aside, due from today to the period end',
      () {
        final result = enumerator.forBudget(
          budget: budget(),
          bills: [
            bill(id: 'a', budgetId: null, due: DateTime(2026, 8, 15)),
            // Weekly: Aug 12, 19, 26 — one bill, three occurrences.
            bill(
              id: 'b',
              budgetId: null,
              amount: 100,
              due: DateTime(2026, 8, 12),
              recurrence: RecurrenceType.weekly,
            ),
            // Overdue before today: not counted.
            bill(id: 'c', budgetId: null, due: DateTime(2026, 8, 5)),
            // After the period end: not counted.
            bill(id: 'd', budgetId: null, due: DateTime(2026, 9, 5)),
            // Another currency: not counted.
            bill(
              id: 'e',
              budgetId: null,
              currency: 'USD',
              due: DateTime(2026, 8, 15),
            ),
            // Paid: not counted.
            bill(
              id: 'f',
              budgetId: null,
              isPaid: true,
              due: DateTime(2026, 8, 15),
            ),
          ],
          budgetsById: {},
          today: today,
        );

        expect(result.occurrences, isEmpty);
        expect(
          result.unlinked,
          const UnlinkedCommitmentSummary(count: 2, total: 800),
        );
      },
    );

    test('includes bills linked to an ended, archived or deleted budget', () {
      final july = budget(
        id: 'jul',
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 31),
      );
      final archived = budget(id: 'old', archived: true);
      final result = enumerator.forBudget(
        budget: budget(),
        bills: [
          bill(
            id: 'rent',
            budgetId: 'jul',
            amount: 1000,
            due: DateTime(2026, 7, 20),
            recurrence: RecurrenceType.monthly,
          ),
          bill(
            id: 'gym',
            budgetId: 'old',
            amount: 50,
            due: DateTime(2026, 8, 20),
          ),
          bill(
            id: 'tax',
            budgetId: 'gone',
            amount: 7,
            due: DateTime(2026, 8, 21),
          ),
        ],
        budgetsById: {'jul': july, 'old': archived},
        today: today,
      );

      // Rent's Jul 20 occurrence is overdue and owed to July; its Aug 20
      // occurrence is in no budget.
      expect(
        result.unlinked,
        const UnlinkedCommitmentSummary(count: 3, total: 1057),
      );
      expect(result.occurrences, isEmpty);
    });

    test('excludes bills another budget sets aside, but not occurrences '
        'outside that budget', () {
      final shortRunning = budget(
        id: 'first-half',
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 15),
      );
      final september = budget(
        id: 'sep',
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 30),
      );
      final result = enumerator.forBudget(
        budget: budget(),
        bills: [
          // Set aside by the running first-half budget.
          bill(id: 'in', budgetId: 'first-half', due: DateTime(2026, 8, 14)),
          // Linked to it but due after it ends.
          bill(
            id: 'out',
            budgetId: 'first-half',
            amount: 70,
            due: DateTime(2026, 8, 20),
          ),
          // Linked to September, which has not started and does not
          // contain Aug 25.
          bill(
            id: 'early',
            budgetId: 'sep',
            amount: 30,
            due: DateTime(2026, 8, 25),
          ),
        ],
        budgetsById: {'first-half': shortRunning, 'sep': september},
        today: today,
      );

      expect(
        result.unlinked,
        const UnlinkedCommitmentSummary(count: 2, total: 100),
      );
    });

    test('a budget that has not started discloses from its start', () {
      final september = budget(
        id: 'sep',
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 30),
      );
      final result = enumerator.forBudget(
        budget: september,
        bills: [
          bill(id: 'aug-only', budgetId: null, due: DateTime(2026, 8, 20)),
          bill(
            id: 'sep',
            budgetId: null,
            amount: 40,
            due: DateTime(2026, 9, 3),
          ),
        ],
        budgetsById: {'sep': september},
        today: today,
      );
      expect(
        result.unlinked,
        const UnlinkedCommitmentSummary(count: 1, total: 40),
      );
    });

    test('an ended budget discloses nothing', () {
      final july = budget(
        id: 'jul',
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 31),
      );
      final result = enumerator.forBudget(
        budget: july,
        bills: [bill(budgetId: null, due: DateTime(2026, 7, 20))],
        budgetsById: {'jul': july},
        today: today,
      );
      expect(result.unlinked.isEmpty, isTrue);
    });
  });

  group('billsNotSetAside (Link bills candidates)', () {
    test('lists exactly the bills counted as not linked, plus other '
        'currencies, soonest first', () {
      final july = budget(
        id: 'jul',
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 31),
      );
      final bills = [
        // Not linked, due in the period.
        bill(
          id: 'water',
          budgetId: null,
          amount: 30,
          due: DateTime(2026, 8, 25),
        ),
        // Linked to an ended budget; next occurrence in no budget.
        bill(
          id: 'rent',
          budgetId: 'jul',
          amount: 1000,
          due: DateTime(2026, 7, 20),
          recurrence: RecurrenceType.monthly,
        ),
        // Already set aside here.
        bill(id: 'gym', amount: 50, due: DateTime(2026, 8, 20)),
        // Paid.
        bill(
          id: 'old',
          budgetId: null,
          due: DateTime(2026, 8, 12),
          isPaid: true,
        ),
        // After the period.
        bill(id: 'later', budgetId: null, due: DateTime(2026, 9, 2)),
        // Another currency.
        bill(
          id: 'usd',
          budgetId: null,
          currency: 'USD',
          amount: 9,
          due: DateTime(2026, 8, 15),
        ),
      ];
      final budgetsById = {'jul': july, 'aug': budget()};

      final candidates = enumerator.billsNotSetAside(
        budget: budget(),
        bills: bills,
        budgetsById: budgetsById,
        today: today,
      );
      final summary = enumerator
          .forBudget(
            budget: budget(),
            bills: bills,
            budgetsById: budgetsById,
            today: today,
          )
          .unlinked;

      expect(candidates.map((b) => b.id), ['rent', 'usd', 'water']);
      final sameCurrency = candidates.where((b) => b.currency == 'INR');
      expect(sameCurrency, hasLength(summary.count));
    });

    test(
      'a bill the running budget\'s neighbour sets aside is not offered',
      () {
        final firstHalf = budget(
          id: 'first-half',
          start: DateTime(2026, 8, 1),
          end: DateTime(2026, 8, 15),
        );
        final candidates = enumerator.billsNotSetAside(
          budget: budget(),
          bills: [
            bill(id: 'in', budgetId: 'first-half', due: DateTime(2026, 8, 14)),
          ],
          budgetsById: {'first-half': firstHalf},
          today: today,
        );
        expect(candidates, isEmpty);
      },
    );
  });
  group('setsAsideCurrentOccurrence (review: paid-outside dialog)', () {
    bool setsAside(BillEntity b, BudgetEntity? to) =>
        BillOccurrenceEnumerator.setsAsideCurrentOccurrence(b, to, today);

    test('true exactly when forBudget deducts the current occurrence', () {
      final cases = <(BillEntity, BudgetEntity?)>[
        (bill(due: DateTime(2026, 8, 20)), budget()),
        // Overdue from before the start, carried into a running budget.
        (bill(due: DateTime(2026, 7, 20)), budget()),
        // Due after the end.
        (bill(due: DateTime(2026, 9, 5)), budget()),
        // Not started yet, due inside / before its period.
        (
          bill(due: DateTime(2026, 9, 5)),
          budget(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30)),
        ),
        (
          bill(due: DateTime(2026, 8, 20)),
          budget(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30)),
        ),
      ];
      for (final (b, to) in cases) {
        final deducted = enumerator
            .forBudget(budget: to!, bills: [b], budgetsById: {}, today: today)
            .occurrences
            .any((o) => o.dueDate == b.dueDate);
        expect(setsAside(b, to), deducted, reason: '${b.dueDate} in $to');
      }
    });

    test('false when the budget sets nothing aside', () {
      final rent = bill(due: DateTime(2026, 8, 20));
      expect(setsAside(rent, null), isFalse);
      expect(setsAside(rent, budget(archived: true)), isFalse);
      expect(setsAside(rent, budget(currency: 'USD')), isFalse);
      expect(setsAside(bill(due: DateTime(2026, 9, 10)), budget()), isFalse);
      expect(
        setsAside(
          bill(due: DateTime(2026, 7, 20)),
          budget(start: DateTime(2026, 7, 1), end: DateTime(2026, 7, 31)),
        ),
        isFalse,
        reason: 'an ended budget ignores bills',
      );
      expect(
        setsAside(bill(due: DateTime(2026, 8, 20), isPaid: true), budget()),
        isFalse,
      );
      expect(
        setsAside(
          bill(due: DateTime(2026, 8, 20), budgetId: 'other'),
          budget(),
        ),
        isFalse,
      );
    });
  });
}
