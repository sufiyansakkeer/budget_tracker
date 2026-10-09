import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/currency/currency_formatter.dart';
import 'package:monivo/features/budget/domain/entities/budget_calculation_input.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/commitment_occurrence.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/currency_excluded_summary.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_entity.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_input.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_reason.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_status.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/unlinked_commitment_summary.dart';
import 'package:monivo/features/budget/domain/services/budget_calculation_service.dart';
import 'package:monivo/features/budget/domain/services/safe_to_spend_calculator.dart';

// Fixture period: 1–30 Oct 2026 (30 days). On 11 Oct: daysPassed 11,
// remainingDays 20, completed days 10.
final _start = DateTime(2026, 10, 1);
final _end = DateTime(2026, 10, 30);
final _oct11 = DateTime(2026, 10, 11);

CommitmentOccurrence _bill(
  String id,
  double amount,
  DateTime due, {
  bool overdue = false,
}) => CommitmentOccurrence(
  billId: id,
  title: 'Bill $id',
  amount: amount,
  dueDate: due,
  isOverdue: overdue,
);

SafeToSpendInput _input({
  String currency = 'INR',
  DateTime? start,
  DateTime? end,
  DateTime? today,
  double amount = 3000,
  double periodSpent = 0,
  double todaySpent = 0,
  double committedInPeriod = 0,
  double committedToday = 0,
  List<CommitmentOccurrence> commitments = const [],
  bool billsUnavailable = false,
  CurrencyExcludedSummary currencyExcluded = CurrencyExcludedSummary.none,
  UnlinkedCommitmentSummary unlinked = UnlinkedCommitmentSummary.none,
  double? reserved,
  double? savings,
}) => SafeToSpendInput(
  budgetId: 'b1',
  budgetName: 'October',
  currency: currency,
  startDate: start ?? _start,
  endDate: end ?? _end,
  today: today ?? _oct11,
  budgetAmount: amount,
  periodSpent: periodSpent,
  todaySpent: todaySpent,
  committedSpentInPeriod: committedInPeriod,
  committedSpentToday: committedToday,
  commitments: billsUnavailable ? null : commitments,
  currencyExcluded: currencyExcluded,
  unlinked: unlinked,
  reservedAmount: reserved,
  savingsTarget: savings,
);

void main() {
  late BudgetCalculationService service;
  late SafeToSpendCalculator calculator;

  setUp(() {
    service = BudgetCalculationService();
    calculator = SafeToSpendCalculator(service);
  });

  SafeToSpendEntity run(SafeToSpendInput input) => calculator.calculate(input);

  group('1. normal budget (no deductions)', () {
    test('daily = (remaining + today discretionary) ÷ remaining days', () {
      final r = run(_input(periodSpent: 800, todaySpent: 50));

      expect(r.status, SafeToSpendStatus.onTrack);
      expect(r.totalDays, 30);
      expect(r.daysPassed, 11);
      expect(r.remainingDays, 20);
      expect(r.availableBalance, 2200);
      expect(r.upcomingCommitments, 0);
      expect(r.rawSpendable, 2200);
      expect(r.freeToSpend, 2200);
      expect(r.shortfall, 0);
      expect(r.spendableAtStartOfToday, 2250);
      expect(r.dailySafeToSpend, 112.5);
      expect(r.remainingToday, 62.5);
      expect(r.overToday, 0);
      expect(r.baselineDaily, 112.5);
      expect(r.allowanceReduction, 0);
      expect(r.reasons, isEmpty);
      expect(r.reservedAmount, isNull);
      expect(r.savingsTarget, isNull);
      expect(r.remainingSavingsTarget, isNull);
      expect(r.commitmentsAvailable, isTrue);
      expect(r.savingsContributionsTracked, isFalse);
      expect(r.isRunning, isTrue);
    });

    test('forecast uses completed days only', () {
      final f = run(_input(periodSpent: 800, todaySpent: 50)).forecast!;

      expect(f.isReliable, isTrue);
      expect(f.completedDays, 10);
      expect(f.averageDaily, 75);
      // today projected = max(50, 75) → 25 more today, then 75 × 19.
      expect(f.projectedDiscretionarySpending, 2250);
      expect(f.projectedPeriodSpending, 2250);
      expect(f.projectedEndBalance, 750);
      expect(f.projectedMargin, 750);
      expect(f.exhaustionDate, isNull);
      expect(f.paceRatio, closeTo(75 / 112.5, 1e-12));
    });

    test('daily matches the summary formula exactly with no deductions', () {
      // 15000 over 21 days is not a terminating decimal: the engine must
      // return the same unfloored quotient as buildSummary.
      for (final spent in [0.0, 1234.56, 7000.0]) {
        for (final today in [0.0, 99.99, 400.0]) {
          final total = spent + today;
          final r = run(
            _input(
              amount: 15000,
              start: DateTime(2026, 10, 10),
              end: DateTime(2026, 10, 30),
              today: DateTime(2026, 10, 10, 15, 30),
              periodSpent: total,
              todaySpent: today,
            ),
          );
          final summary = service.buildSummary(
            BudgetCalculationInput(
              monthlyAmount: 15000,
              totalSpent: total,
              todaySpending: today,
              referenceDate: DateTime(2026, 10, 10),
              startDate: DateTime(2026, 10, 10),
              endDate: DateTime(2026, 10, 30),
            ),
            currency: 'INR',
          );
          expect(r.dailySafeToSpend, closeTo(summary.dailySafeSpending, 1e-9));
          expect(r.remainingDays, summary.remainingDays);
          expect(r.daysPassed, summary.daysPassed);
        }
      }
    });

    test('budget_flows invariant: 1000 holds through the day', () {
      final ten = DateTime(2026, 10, 10);
      final end = DateTime(2026, 10, 19);
      SafeToSpendEntity at(double today) => run(
        _input(
          amount: 10000,
          start: ten,
          end: end,
          today: ten,
          periodSpent: today,
          todaySpent: today,
        ),
      );
      expect(at(0).dailySafeToSpend, 1000);
      expect(at(400).dailySafeToSpend, 1000);
      expect(at(400).remainingToday, 600);
      expect(at(1300).dailySafeToSpend, 1000);
      expect(at(1300).overToday, 300);
      // Next day: 9000 left over 9 days.
      final next = run(
        _input(
          amount: 10000,
          start: ten,
          end: end,
          today: DateTime(2026, 10, 11),
          periodSpent: 1000,
        ),
      );
      expect(next.dailySafeToSpend, 1000);
    });
  });

  group('2–5. deductions', () {
    test('2. bills due are deducted before dividing', () {
      final r = run(
        _input(
          periodSpent: 800,
          todaySpent: 50,
          commitments: [
            _bill('rent', 300, DateTime(2026, 10, 15)),
            _bill('net', 200, DateTime(2026, 10, 25)),
          ],
        ),
      );

      expect(r.upcomingCommitments, 500);
      expect(r.rawSpendable, 1700);
      expect(r.freeToSpend, 1700);
      expect(r.spendableAtStartOfToday, 1750);
      expect(r.dailySafeToSpend, 87.5);
      expect(r.baselineDaily, 112.5);
      expect(r.allowanceReduction, 25);
      expect(r.status, SafeToSpendStatus.onTrack);
      expect(r.commitments.map((c) => c.billId), ['rent', 'net']);
      expect(r.reasons, [
        const AllowanceReducedReason(
          amount: 25,
          billsTotal: 500,
          reserved: null,
          savings: null,
        ),
        BillsDueReason(total: 500, count: 2, nextDue: DateTime(2026, 10, 15)),
      ]);
      // Projection includes the bills still due.
      expect(r.forecast!.projectedPeriodSpending, 2750);
      expect(r.forecast!.projectedMargin, 250);
    });

    test('3. kept-aside money is deducted', () {
      final r = run(_input(periodSpent: 800, todaySpent: 50, reserved: 500));

      expect(r.reservedAmount, 500);
      expect(r.rawSpendable, 1700);
      expect(r.dailySafeToSpend, 87.5);
      expect(r.reasons.first, isA<AllowanceReducedReason>());
      final reduced = r.reasons.first as AllowanceReducedReason;
      expect(reduced.reserved, 500);
      expect(reduced.savings, isNull);
      expect(reduced.billsTotal, 0);
    });

    test('4. savings goal is deducted in full (contributions untracked)', () {
      final r = run(_input(periodSpent: 800, todaySpent: 50, savings: 500));

      expect(r.savingsTarget, 500);
      expect(r.remainingSavingsTarget, 500);
      expect(r.reservedAmount, isNull);
      expect(r.rawSpendable, 1700);
      expect(r.dailySafeToSpend, 87.5);
      expect(r.savingsContributionsTracked, isFalse);
    });

    test('5. bills + kept aside + savings: raw = A − B − C − D', () {
      final r = run(
        _input(
          periodSpent: 800,
          todaySpent: 50,
          commitments: [_bill('rent', 300, DateTime(2026, 10, 15))],
          reserved: 200,
          savings: 100,
        ),
      );

      expect(r.availableBalance, 2200);
      expect(r.totalDeductions, 600);
      expect(
        r.rawSpendable,
        r.availableBalance -
            r.upcomingCommitments -
            r.reservedAmount! -
            r.remainingSavingsTarget!,
      );
      expect(r.rawSpendable, 1600);
      expect(r.dailySafeToSpend, 82.5);
      // margin 150 < 10% of 1650 → careful.
      expect(r.forecast!.projectedMargin, 150);
      expect(
        r.forecast!.projectedMargin,
        r.forecast!.projectedEndBalance! - 200 - 100,
      );
      expect(r.status, SafeToSpendStatus.spendingCarefully);
    });

    test('0 kept aside is "set to 0", distinct from not set', () {
      final r = run(_input(reserved: 0, savings: 0));
      expect(r.reservedAmount, 0);
      expect(r.remainingSavingsTarget, 0);
      expect(r.allowanceReduction, 0);
    });

    test('negative kept-aside / savings (corrupt data) never add money', () {
      final r = run(_input(reserved: -500, savings: -100));
      expect(r.rawSpendable, 3000);
      expect(r.reservedAmount, 0);
      expect(r.remainingSavingsTarget, 0);
    });

    test('duplicate (bill, due date) occurrences are deducted once', () {
      final r = run(
        _input(
          commitments: [
            _bill('b', 100, DateTime(2026, 10, 20)),
            _bill('a', 50, DateTime(2026, 10, 12)),
            _bill('b', 100, DateTime(2026, 10, 20, 9)),
            _bill('b', 100, DateTime(2026, 10, 27)),
          ],
        ),
      );
      expect(r.upcomingCommitments, 250);
      expect(r.commitments.map((c) => (c.billId, c.dueDate.day)), [
        ('a', 12),
        ('b', 20),
        ('b', 27),
      ]);
    });

    test('overdue occurrences carried in are deducted and kept flagged', () {
      final r = run(
        _input(
          commitments: [
            _bill('rent', 300, DateTime(2026, 9, 5), overdue: true),
            _bill('rent', 300, DateTime(2026, 10, 5), overdue: true),
          ],
        ),
      );
      expect(r.upcomingCommitments, 600);
      expect(r.commitments.every((c) => c.isOverdue), isTrue);
      final due = r.reasons.whereType<BillsDueReason>().single;
      expect(due.nextDue, DateTime(2026, 9, 5));
      expect(due.count, 2);
    });
  });

  group('8. committed bill payments', () {
    test('paying a set-aside bill today leaves the daily amount unchanged', () {
      final before = run(
        _input(
          periodSpent: 1000,
          todaySpent: 50,
          commitments: [_bill('rent', 300, DateTime(2026, 10, 15))],
        ),
      );
      final after = run(
        _input(
          periodSpent: 1300,
          todaySpent: 350,
          committedInPeriod: 300,
          committedToday: 300,
        ),
      );

      expect(before.dailySafeToSpend, 87.5);
      expect(after.dailySafeToSpend, 87.5);
      expect(after.rawSpendable, before.rawSpendable);
      expect(after.todaySpent, 350);
      expect(after.todayDiscretionary, 50);
      expect(after.committedSpentToday, 300);
      expect(after.remainingToday, 37.5);
      expect(after.overToday, 0);
      expect(after.status, before.status);
      expect(after.forecast!.averageDaily, before.forecast!.averageDaily);
      expect(after.reasons, contains(const BillPaymentsTodayReason(300)));
    });

    test('a bill payment that was not set aside is ordinary spending', () {
      // committed* stay 0: the use case only passes set-aside payments.
      final before = run(_input(periodSpent: 1000));
      final after = run(_input(periodSpent: 1200, todaySpent: 200));
      expect(before.dailySafeToSpend, 100);
      expect(after.dailySafeToSpend, 100);
      expect(after.overToday, 100);
      expect(after.status, SafeToSpendStatus.overDailyAllowance);
    });
  });

  group('9–12. negative and over states', () {
    final oct26 = DateTime(2026, 10, 26);

    test(
      '9. negative intermediate: today\'s overspend is not overcommitted',
      () {
        // Start of day: A 500, bill 450, 5 days left → S0 50, daily 10.
        final morning = run(
          _input(
            today: oct26,
            periodSpent: 2500,
            commitments: [_bill('rent', 450, DateTime(2026, 10, 28))],
          ),
        );
        expect(morning.remainingDays, 5);
        expect(morning.dailySafeToSpend, 10);

        final evening = run(
          _input(
            today: oct26,
            periodSpent: 2580,
            todaySpent: 80,
            commitments: [_bill('rent', 450, DateTime(2026, 10, 28))],
          ),
        );
        expect(evening.availableBalance, 420);
        expect(evening.rawSpendable, -30);
        expect(evening.freeToSpend, 0);
        expect(evening.shortfall, 30);
        expect(evening.spendableAtStartOfToday, 50);
        expect(evening.dailySafeToSpend, 10);
        expect(evening.overToday, 70);
        expect(evening.remainingToday, 0);
        // Over today outranks the (also negative) forecast.
        expect(evening.forecast!.projectedMargin, lessThan(0));
        expect(evening.status, SafeToSpendStatus.overDailyAllowance);
        expect(evening.reasons.first, const OverTodayReason(70));
        expect(evening.reasons.whereType<OvercommittedByReason>(), isEmpty);

        // Next day the deficit is real: overcommitted.
        final tomorrow = run(
          _input(
            today: DateTime(2026, 10, 27),
            periodSpent: 2580,
            commitments: [_bill('rent', 450, DateTime(2026, 10, 28))],
          ),
        );
        expect(tomorrow.spendableAtStartOfToday, -30);
        expect(tomorrow.dailySafeToSpend, 0);
        expect(tomorrow.status, SafeToSpendStatus.overcommitted);
        expect(tomorrow.reasons.first, const OvercommittedByReason(30));
      },
    );

    test('10. nothing free (bills = balance, S0 = 0) → spend carefully', () {
      final r = run(
        _input(
          today: DateTime(2026, 10, 3),
          periodSpent: 2000,
          commitments: [_bill('rent', 1000, DateTime(2026, 10, 15))],
        ),
      );
      expect(r.spendableAtStartOfToday, 0);
      expect(r.dailySafeToSpend, 0);
      expect(r.freeToSpend, 0);
      expect(r.shortfall, 0);
      expect(r.status, SafeToSpendStatus.spendingCarefully);
      expect(r.reasons.map((e) => e.runtimeType), [
        NothingFreeToSpendReason,
        AllowanceReducedReason,
        BillsDueReason,
        ForecastInsufficientReason,
      ]);
    });

    test('10. zero available with no deductions is never on track', () {
      final r = run(_input(today: DateTime(2026, 10, 3), periodSpent: 3000));
      expect(r.availableBalance, 0);
      expect(r.dailySafeToSpend, 0);
      expect(r.status, SafeToSpendStatus.spendingCarefully);
      expect(r.reasons.first, const NothingFreeToSpendReason());
    });

    test('11. expenses above the budget → over budget first', () {
      final r = run(_input(periodSpent: 3200, todaySpent: 100));
      expect(r.availableBalance, -200);
      expect(r.freeToSpend, 0);
      expect(r.shortfall, 200);
      expect(r.dailySafeToSpend, 0);
      expect(r.overToday, 100);
      expect(r.status, SafeToSpendStatus.overBudget);
      expect(r.reasons.first, const OverBudgetByReason(200));
      expect(r.reasons, contains(const OverTodayReason(100)));
      // Over budget is not reported as overcommitted as well.
      expect(r.reasons.whereType<OvercommittedByReason>(), isEmpty);
    });

    test('12. over today\'s allowance only', () {
      final r = run(_input(periodSpent: 1000, todaySpent: 300));
      expect(r.dailySafeToSpend, 115);
      expect(r.overToday, 185);
      expect(r.remainingToday, 0);
      expect(r.forecast!.projectedMargin, greaterThanOrEqualTo(0));
      expect(r.status, SafeToSpendStatus.overDailyAllowance);
      expect(r.reasons, [const OverTodayReason(185)]);
    });

    test('spending exactly today\'s amount is not over', () {
      final r = run(_input(periodSpent: 1005, todaySpent: 105));
      // S0 2100 / 20 = 105.
      expect(r.dailySafeToSpend, 105);
      expect(r.overToday, 0);
      expect(r.status, isNot(SafeToSpendStatus.overDailyAllowance));
    });
  });

  group('13–14. forecast', () {
    test('13. projected overspending → at risk with exhaustion date', () {
      final r = run(
        _input(
          periodSpent: 1800,
          commitments: [_bill('rent', 300, DateTime(2026, 10, 20))],
        ),
      );
      final f = r.forecast!;

      expect(r.rawSpendable, 900);
      expect(r.dailySafeToSpend, 45);
      expect(f.averageDaily, 180);
      expect(f.projectedDiscretionarySpending, 5400);
      expect(f.projectedPeriodSpending, 5700);
      expect(f.projectedEndBalance, -2700);
      expect(f.projectedMargin, -2700);
      // 180 today leaves 720 = four more days: gone on 16 Oct.
      expect(f.exhaustionDate, DateTime(2026, 10, 16));
      expect(f.paceRatio, 4);
      expect(r.status, SafeToSpendStatus.budgetAtRisk);
      expect(
        r.reasons.first,
        const AtRiskReason(averageDaily: 180, deficit: 2700),
      );
    });

    test('exhaustion is today when today\'s pace already uses it up', () {
      final r = run(
        _input(
          periodSpent: 1800,
          commitments: [_bill('rent', 1100, DateTime(2026, 10, 20))],
        ),
      );
      // raw 100 < today's projected 180.
      expect(r.forecast!.exhaustionDate, _oct11);
    });

    test('margin within 10% of S0 → spend carefully', () {
      final r = run(_input(periodSpent: 1000, todaySpent: 50));
      // raw 2000, S0 2050, avg 95: margin 2000 − (45 + 95 × 19) = 150 < 205.
      expect(r.forecast!.projectedMargin, 150);
      expect(r.status, SafeToSpendStatus.spendingCarefully);
    });

    test('today ≥ 80% of the daily amount → spend carefully', () {
      final r = run(_input(periodSpent: 990, todaySpent: 90));
      expect(r.dailySafeToSpend, 105);
      expect(r.status, SafeToSpendStatus.spendingCarefully);
      final under = run(_input(periodSpent: 983, todaySpent: 83));
      expect(under.dailySafeToSpend, closeTo(105, 1e-9));
      expect(under.status, SafeToSpendStatus.onTrack);
    });

    test('14. fewer than 3 completed days → insufficient', () {
      final r = run(
        _input(today: DateTime(2026, 10, 3), periodSpent: 200, todaySpent: 50),
      );
      expect(r.forecast!.isReliable, isFalse);
      expect(r.forecast!.daysNeeded, 1);
      expect(r.forecast!.hasAnyExpense, isTrue);
      expect(r.forecast!.projectedMargin, isNull);
      expect(r.forecast!.exhaustionDate, isNull);
      expect(
        r.reasons.last,
        const ForecastInsufficientReason(daysNeeded: 1, hasAnyExpense: true),
      );
    });

    test('14. first day of the period needs 3 more days', () {
      final r = run(_input(today: _start));
      expect(r.daysPassed, 1);
      expect(r.forecast!.daysNeeded, 3);
      expect(r.forecast!.hasAnyExpense, isFalse);
    });

    test('14. enough days but no discretionary spending yet', () {
      final none = run(_input());
      expect(none.forecast!.isReliable, isFalse);
      expect(none.forecast!.daysNeeded, 0);
      expect(none.forecast!.hasAnyExpense, isFalse);

      final todayOnly = run(_input(periodSpent: 40, todaySpent: 40));
      expect(todayOnly.forecast!.daysNeeded, 1);
      expect(todayOnly.forecast!.hasAnyExpense, isTrue);
    });

    test('14. bill payments alone never make the forecast reliable', () {
      final r = run(_input(periodSpent: 500, committedInPeriod: 500));
      expect(r.forecast!.isReliable, isFalse);
      expect(r.forecast!.hasAnyExpense, isFalse);
    });

    test('exhaustion == null ⟺ projected margin ≥ 0 (property)', () {
      var reliable = 0;
      var withDate = 0;
      for (final day in [4, 11, 20, 29, 30]) {
        final today = DateTime(2026, 10, day);
        for (final spentBefore in [10.0, 333.33, 900.0, 1500.0, 2400.0]) {
          for (final spentToday in [0.0, 25.5, 180.0, 700.0]) {
            for (final bills in [0.0, 150.0, 999.99]) {
              final r = run(
                _input(
                  today: today,
                  periodSpent: spentBefore + spentToday,
                  todaySpent: spentToday,
                  commitments: [
                    if (bills > 0) _bill('x', bills, DateTime(2026, 10, 30)),
                  ],
                  reserved: 120,
                ),
              );
              final f = r.forecast!;
              if (!f.isReliable) continue;
              reliable++;
              expect(
                f.exhaustionDate == null,
                f.projectedMargin! >= 0,
                reason: 'day $day before $spentBefore today $spentToday',
              );
              expect(
                f.projectedMargin,
                closeTo(f.projectedEndBalance! - 120, 1e-6),
              );
              final date = f.exhaustionDate;
              if (date != null) {
                withDate++;
                expect(date.isBefore(r.today), isFalse);
                expect(date.isAfter(_end), isFalse);
              }
            }
          }
        }
      }
      expect(reliable, greaterThan(100));
      expect(withDate, greaterThan(10));
    });

    test('exhaustion date matches a day-by-day simulation', () {
      for (final spentBefore in [1200.0, 1500.0, 2000.0, 2500.0]) {
        for (final spentToday in [0.0, 300.0]) {
          final r = run(
            _input(
              periodSpent: spentBefore + spentToday,
              todaySpent: spentToday,
              commitments: [_bill('x', 200, DateTime(2026, 10, 30))],
            ),
          );
          final f = r.forecast!;
          final avg = f.averageDaily!;
          // Today spends max(today so far, avg); every later day spends avg.
          // Money runs out on the first day that starts with less than a
          // full day's spending.
          final todayProjected = r.todayDiscretionary > avg
              ? r.todayDiscretionary
              : avg;
          var left = r.rawSpendable - (todayProjected - r.todayDiscretionary);
          DateTime? simulated;
          if (left < 0) {
            simulated = _oct11;
          } else {
            var day = DateTime(2026, 10, 12);
            while (!day.isAfter(_end)) {
              if (left < avg) {
                simulated = day;
                break;
              }
              left -= avg;
              day = DateTime(day.year, day.month, day.day + 1);
            }
          }
          expect(
            f.exhaustionDate,
            simulated,
            reason: 'before $spentBefore today $spentToday',
          );
        }
      }
    });
  });

  group('15–17. phases', () {
    test('15. future start: not started, bills listed, nothing to spend', () {
      final r = run(
        _input(
          today: DateTime(2026, 9, 25, 18),
          todaySpent: 100,
          commitments: [_bill('rent', 300, DateTime(2026, 10, 5))],
        ),
      );
      expect(r.status, SafeToSpendStatus.notStarted);
      expect(r.isRunning, isFalse);
      expect(r.daysUntilStart, 6);
      expect(r.daysPassed, 0);
      expect(r.remainingDays, 30);
      expect(r.dailySafeToSpend, 0);
      expect(r.todaySpent, 0);
      expect(r.todayDiscretionary, 0);
      expect(r.upcomingCommitments, 300);
      expect(r.freeToSpend, 2700);
      expect(r.forecast, isNull);
      expect(r.today, DateTime(2026, 9, 25));
      expect(r.reasons, [
        BillsDueReason(total: 300, count: 1, nextDue: DateTime(2026, 10, 5)),
      ]);
    });

    test('16. final day', () {
      final r = run(_input(today: _end, periodSpent: 2900, todaySpent: 50));
      expect(r.remainingDays, 1);
      expect(r.daysPassed, 30);
      expect(r.dailySafeToSpend, 150);
      expect(r.remainingToday, 100);
      expect(r.forecast!.exhaustionDate, isNull);
      expect(r.status, SafeToSpendStatus.onTrack);

      final tight = run(_input(today: _end, periodSpent: 2990, todaySpent: 50));
      expect(tight.dailySafeToSpend, 60);
      expect(tight.forecast!.projectedMargin, lessThan(0));
      expect(tight.forecast!.exhaustionDate, _end);
      expect(tight.status, SafeToSpendStatus.budgetAtRisk);
    });

    test('17. expired: period ended with the final balance', () {
      final r = run(
        _input(
          today: DateTime(2026, 11, 2),
          periodSpent: 2500,
          todaySpent: 40,
          commitments: [_bill('rent', 300, DateTime(2026, 10, 5))],
        ),
      );
      expect(r.status, SafeToSpendStatus.periodEnded);
      expect(r.availableBalance, 500);
      expect(r.dailySafeToSpend, 0);
      expect(r.remainingDays, 0);
      expect(r.daysPassed, 30);
      expect(r.todaySpent, 0);
      expect(r.forecast, isNull);
      expect(r.reasons, isEmpty);

      final over = run(_input(today: DateTime(2026, 11, 2), periodSpent: 3100));
      expect(over.status, SafeToSpendStatus.periodEnded);
      expect(over.reasons, [const OverBudgetByReason(100)]);
    });

    test('the day after the end is ended, the start day is running', () {
      expect(
        run(_input(today: DateTime(2026, 10, 31))).status,
        SafeToSpendStatus.periodEnded,
      );
      expect(run(_input(today: DateTime(2026, 10, 1, 0, 1))).isRunning, isTrue);
      expect(
        run(_input(today: DateTime(2026, 9, 30, 23, 59))).status,
        SafeToSpendStatus.notStarted,
      );
    });
  });

  group('status precedence', () {
    test('today\'s overspend never makes overcommitted', () {
      // Start of day: A 1000, bills 900 → S0 100 whatever is spent today.
      for (var today = 0.0; today <= 5000; today += 250) {
        final r = run(
          _input(
            periodSpent: 2000 + today,
            todaySpent: today,
            commitments: [_bill('rent', 900, DateTime(2026, 10, 20))],
          ),
        );
        expect(r.spendableAtStartOfToday, 100);
        expect(r.status, isNot(SafeToSpendStatus.overcommitted));
        expect(r.reasons.whereType<OvercommittedByReason>(), isEmpty);
        if (r.availableBalance < 0) {
          expect(r.status, SafeToSpendStatus.overBudget);
        }
      }
    });

    test('overBudget > overcommitted > overDailyAllowance > atRisk', () {
      final overBudget = run(
        _input(
          periodSpent: 3100,
          todaySpent: 100,
          commitments: [_bill('rent', 900, DateTime(2026, 10, 20))],
        ),
      );
      expect(overBudget.status, SafeToSpendStatus.overBudget);

      final overcommitted = run(
        _input(
          periodSpent: 2500,
          todaySpent: 100,
          commitments: [_bill('rent', 900, DateTime(2026, 10, 20))],
        ),
      );
      expect(overcommitted.spendableAtStartOfToday, -300);
      expect(overcommitted.overToday, 100);
      expect(overcommitted.status, SafeToSpendStatus.overcommitted);
      // The amount is the shortfall against what is left now (raw −400),
      // the figure the breakdown shows, not the start-of-day −S0 (300).
      expect(overcommitted.shortfall, 400);
      expect(overcommitted.reasons.first, const OvercommittedByReason(400));
    });

    test('overcommitted with spending today reports the breakdown shortfall '
        '(review: −S0 contradicted "Remaining in budget")', () {
      // 22,000 budget, 21,300 spent (300 of it today), 1,500 bill due.
      final r = run(
        _input(
          amount: 22000,
          periodSpent: 21300,
          todaySpent: 300,
          commitments: [_bill('rent', 1500, DateTime(2026, 10, 20))],
        ),
      );
      expect(r.availableBalance, 700);
      expect(r.rawSpendable, -800);
      expect(r.spendableAtStartOfToday, -500);
      expect(r.status, SafeToSpendStatus.overcommitted);
      expect(r.shortfall, 800);
      expect(r.reasons.first, const OvercommittedByReason(800));
    });

    test('bills unavailable caps the status and leads the reasons', () {
      final r = run(
        _input(periodSpent: 800, todaySpent: 50, billsUnavailable: true),
      );
      expect(r.commitmentsAvailable, isFalse);
      expect(r.upcomingCommitments, 0);
      expect(r.commitments, isEmpty);
      expect(r.dailySafeToSpend, 112.5);
      expect(r.status, SafeToSpendStatus.spendingCarefully);
      expect(r.reasons.first, const BillsUnavailableReason());
    });

    test('bills unavailable never hides a worse status', () {
      final r = run(
        _input(periodSpent: 1000, todaySpent: 300, billsUnavailable: true),
      );
      expect(r.status, SafeToSpendStatus.overDailyAllowance);
      expect(r.reasons.first, const BillsUnavailableReason());
    });

    test('currency-excluded bills cap the status', () {
      const excluded = CurrencyExcludedSummary(
        count: 2,
        totalsByCurrency: {'USD': 40},
      );
      final r = run(
        _input(periodSpent: 800, todaySpent: 50, currencyExcluded: excluded),
      );
      expect(r.status, SafeToSpendStatus.spendingCarefully);
      expect(r.reasons, [
        const BillsCurrencyExcludedReason(
          count: 2,
          totalsByCurrency: {'USD': 40},
        ),
      ]);
    });

    test('unlinked bills are disclosed, not deducted', () {
      final r = run(
        _input(
          periodSpent: 800,
          todaySpent: 50,
          unlinked: const UnlinkedCommitmentSummary(count: 1, total: 400),
        ),
      );
      expect(r.dailySafeToSpend, 112.5);
      expect(r.status, SafeToSpendStatus.onTrack);
      expect(r.reasons, [const BillsNotLinkedReason(count: 1, total: 400)]);
    });

    test('reasons follow hero priority', () {
      final r = run(
        _input(
          today: DateTime(2026, 10, 2),
          periodSpent: 3300,
          todaySpent: 400,
          committedInPeriod: 100,
          committedToday: 100,
          billsUnavailable: true,
          unlinked: const UnlinkedCommitmentSummary(count: 1, total: 50),
          currencyExcluded: const CurrencyExcludedSummary(
            count: 1,
            totalsByCurrency: {'USD': 10},
          ),
        ),
      );
      expect(r.reasons.map((e) => e.runtimeType), [
        BillsUnavailableReason,
        OverBudgetByReason,
        OverTodayReason,
        BillsNotLinkedReason,
        BillsCurrencyExcludedReason,
        BillPaymentsTodayReason,
        ForecastInsufficientReason,
      ]);
      expect(r.topReason, const BillsUnavailableReason());
    });
  });

  group('21. rounding', () {
    test('OMR keeps 3 decimals exactly', () {
      final r = run(
        _input(
          currency: 'OMR',
          amount: 200.5,
          periodSpent: 48.505,
          commitments: [_bill('gas', 0.6, DateTime(2026, 10, 20))],
        ),
      );
      expect(r.availableBalance, 151.995);
      expect(r.rawSpendable, 151.395);
      expect(r.dailySafeToSpend, closeTo(7.56975, 1e-12));
      final shown = CurrencyFormatter.floorForDisplay(
        r.dailySafeToSpend,
        code: 'OMR',
      );
      expect(shown.amount, 7.569);
      expect(shown.decimalDigits, 3);
    });

    test('OMR 7.600 is not shown as 8', () {
      final r = run(
        _input(
          currency: 'OMR',
          amount: 152,
          start: _oct11,
          end: DateTime(2026, 10, 30),
        ),
      );
      expect(r.dailySafeToSpend, closeTo(7.6, 1e-12));
      expect(
        CurrencyFormatter.formatFloored(r.dailySafeToSpend, code: 'OMR'),
        contains('7.600'),
      );
    });

    test('JPY sums keep form decimals; display floors to whole yen', () {
      final r = run(
        _input(currency: 'JPY', amount: 100000, periodSpent: 33333.5),
      );
      expect(r.availableBalance, 66666.5);
      expect(r.dailySafeToSpend, closeTo(3333.325, 1e-9));
      final shown = CurrencyFormatter.floorForDisplay(
        r.dailySafeToSpend,
        code: 'JPY',
      );
      expect(shown.amount, 3333);
      expect(shown.decimalDigits, 0);
    });

    test('0.1 + 0.2 is exactly 0.3', () {
      final r = run(
        _input(
          amount: 1,
          commitments: [
            _bill('a', 0.1, DateTime(2026, 10, 12)),
            _bill('b', 0.2, DateTime(2026, 10, 13)),
          ],
        ),
      );
      expect(r.upcomingCommitments, 0.3);
      expect(r.rawSpendable, 0.7);
      expect(r.totalDeductions, 0.3);
    });

    test('1000 / 3 is unfloored in the domain; display floors', () {
      final r = run(
        _input(amount: 1000, start: _oct11, end: DateTime(2026, 10, 13)),
      );
      expect(r.dailySafeToSpend, closeTo(1000 / 3, 1e-9));
      final shown = CurrencyFormatter.floorForDisplay(
        r.dailySafeToSpend,
        code: 'INR',
      );
      expect(shown.amount, 333.33);
      expect(shown.amount * 3, lessThanOrEqualTo(1000));
    });
  });

  group('22. calendar edges', () {
    test('leap year: Feb 29 2028 is the last day of a 29-day period', () {
      final r = run(
        _input(
          start: DateTime(2028, 2, 1),
          end: DateTime(2028, 2, 29),
          today: DateTime(2028, 2, 29, 21),
          amount: 2900,
          periodSpent: 2800,
        ),
      );
      expect(r.totalDays, 29);
      expect(r.daysPassed, 29);
      expect(r.remainingDays, 1);
      expect(r.dailySafeToSpend, 100);
    });

    test('month-end: a period crossing month ends counts calendar days', () {
      final r = run(
        _input(
          start: DateTime(2026, 1, 31),
          end: DateTime(2026, 3, 2),
          today: DateTime(2026, 2, 28),
          amount: 3100,
        ),
      );
      expect(r.totalDays, 31);
      expect(r.daysPassed, 29);
      expect(r.remainingDays, 3);
    });

    test('DST-proof arithmetic across 8 Mar and 1 Nov 2026 (local dates)', () {
      expect(
        BudgetCalculationService.calendarDaysBetween(
          DateTime(2026, 3, 8),
          DateTime(2026, 3, 9),
        ),
        1,
      );
      expect(
        BudgetCalculationService.calendarDaysBetween(
          DateTime(2026, 3, 7, 23),
          DateTime(2026, 3, 9, 1),
        ),
        2,
      );
      expect(
        BudgetCalculationService.calendarDaysBetween(
          DateTime(2026, 11, 1),
          DateTime(2026, 11, 2),
        ),
        1,
      );
      expect(
        BudgetCalculationService.calendarDaysBetween(
          DateTime(2026, 3, 8),
          DateTime(2026, 11, 1),
        ),
        238,
      );

      final march = run(
        _input(
          start: DateTime(2026, 3, 1),
          end: DateTime(2026, 3, 31),
          today: DateTime(2026, 3, 9),
          amount: 3100,
        ),
      );
      expect(march.totalDays, 31);
      expect(march.daysPassed, 9);
      expect(march.remainingDays, 23);

      final november = run(
        _input(
          start: DateTime(2026, 10, 25),
          end: DateTime(2026, 11, 7),
          today: DateTime(2026, 11, 1, 12),
          amount: 1400,
        ),
      );
      expect(november.totalDays, 14);
      expect(november.daysPassed, 8);
      expect(november.remainingDays, 7);
    });

    test('exhaustion dates are calendar dates across a DST change', () {
      // Running 1–31 Mar 2026; on 7 Mar avg 180, raw 900: 180 today,
      // then 720 lasts four days (8–11 Mar, across the 8 Mar change) → 12.
      final r = run(
        _input(
          start: DateTime(2026, 3, 1),
          end: DateTime(2026, 3, 31),
          today: DateTime(2026, 3, 7),
          amount: 2880,
          periodSpent: 1080,
          commitments: [_bill('rent', 900, DateTime(2026, 3, 20))],
        ),
      );
      final f = r.forecast!;
      expect(f.averageDaily, 180);
      expect(r.rawSpendable, 900);
      final date = f.exhaustionDate!;
      expect((date.year, date.month, date.day), (2026, 3, 12));
      expect(date.hour, 0);
    });
  });
  group('large amounts (review: 64-bit overflow)', () {
    test('a budget near the input limit forecasts exactly', () {
      // 999,999,999,999.99 INR over the 30-day fixture period.
      final r = run(
        _input(
          amount: 999999999999.99,
          periodSpent: 300000000000,
          reserved: 600000000000,
        ),
      );
      final f = r.forecast!;
      expect(f.isReliable, isTrue);
      // 300bn over 10 completed days: 30bn a day, 20 days left (today
      // included, nothing spent today) → 600bn more.
      expect(f.averageDaily, 30000000000);
      expect(f.projectedPeriodSpending, 900000000000);
      expect(f.projectedEndBalance, closeTo(99999999999.99, 0.01));
      // Raw 99,999,999,999.99 − 600bn still to spend.
      expect(f.projectedMargin, closeTo(-500000000000.01, 0.01));
      expect(r.status, SafeToSpendStatus.budgetAtRisk);
    });

    test('a long period at the limit keeps the margin sign', () {
      // OMR (1,000 units each) just under the input limit: ~1e15 units.
      // 1 Jan 2026 – 31 Dec 2099 on 1 Jan 2060: 12,418 completed days, so
      // raw × days is ~1.2e19 and wrapped negative as a 64-bit int.
      final r = run(
        _input(
          currency: 'OMR',
          amount: 999999999999,
          periodSpent: 1000,
          start: DateTime(2026, 1, 1),
          end: DateTime(2099, 12, 31),
          today: DateTime(2060, 1, 1),
        ),
      );
      final f = r.forecast!;
      expect(f.isReliable, isTrue);
      expect(f.completedDays, 12418);
      expect(f.projectedMargin, greaterThan(999999000000));
      expect(f.exhaustionDate, isNull);
      expect(r.status, SafeToSpendStatus.onTrack);
    });

    test('over today is decided without overflow on a long period', () {
      // 9e14 units spent today × 14,610 days left is ~1.3e19: as a 64-bit
      // int it wrapped negative and today never read as over.
      final r = run(
        _input(
          currency: 'OMR',
          amount: 999999999999,
          periodSpent: 900000000000,
          todaySpent: 900000000000,
          start: DateTime(2060, 1, 1),
          end: DateTime(2099, 12, 31),
          today: DateTime(2060, 1, 1),
        ),
      );
      // 999,999,999,999 ÷ 14,610 ≈ 68,446,269 a day: 900bn is over.
      expect(r.remainingDays, 14610);
      expect(r.dailySafeToSpend, lessThan(900000000000));
      expect(r.status, SafeToSpendStatus.overDailyAllowance);
    });

    test('an amount MoneyMath refuses throws ArgumentError, not '
        'FormatException', () {
      expect(() => run(_input(amount: 1e17)), throwsA(isA<ArgumentError>()));
    });
  });

  group('tomorrow outlook (informational)', () {
    // 1–30 Oct, today 11 Oct: 20 days left including today, 19 after it.

    test('tomorrow = raw ÷ days after today when nothing more is spent', () {
      final e = run(_input(periodSpent: 1000, todaySpent: 100));
      // raw = 3000 − 1000 = 2000; today = (2000 + 100) ÷ 20 = 105.
      expect(e.dailySafeToSpend, closeTo(105, 1e-9));
      expect(e.tomorrowIfNoMoreSpending, closeTo(2000 / 19, 1e-6));
      // Under today's amount: no overspend to spread.
      expect(e.overTodayPerRemainingDay, isNull);
    });

    test('an overspend lowers each later day by over ÷ days after today', () {
      final e = run(_input(periodSpent: 1000, todaySpent: 300));
      // raw = 2000; today = (2000 + 300) ÷ 20 = 115; over by 185.
      expect(e.dailySafeToSpend, closeTo(115, 1e-9));
      expect(e.overToday, closeTo(185, 1e-9));
      expect(e.tomorrowIfNoMoreSpending, closeTo(2000 / 19, 1e-6));
      expect(e.overTodayPerRemainingDay, closeTo(185 / 19, 1e-6));
      // Identity: spending exactly today's amount would have left
      // (2300 − 115) ÷ 19 = 115 for each later day; the spread is the gap.
      expect(
        115 - e.tomorrowIfNoMoreSpending!,
        closeTo(e.overTodayPerRemainingDay!, 1e-6),
      );
    });

    test('there is no tomorrow on the last day of the period', () {
      final e = run(
        _input(
          periodSpent: 1000,
          todaySpent: 300,
          today: DateTime(2026, 10, 30),
        ),
      );
      expect(e.remainingDays, 1);
      expect(e.tomorrowIfNoMoreSpending, isNull);
      expect(e.overTodayPerRemainingDay, isNull);
    });

    test('nothing is projected before the period starts', () {
      final e = run(_input(today: DateTime(2026, 9, 20)));
      expect(e.status, SafeToSpendStatus.notStarted);
      expect(e.tomorrowIfNoMoreSpending, isNull);
      expect(e.overTodayPerRemainingDay, isNull);
    });

    test('no spread is stated once tomorrow is already 0', () {
      // A = 3000 − 3100 = −100: tomorrow floors at 0.
      final e = run(_input(periodSpent: 3100, todaySpent: 200));
      expect(e.overToday, greaterThan(0));
      expect(e.tomorrowIfNoMoreSpending, 0);
      expect(e.overTodayPerRemainingDay, isNull);
    });
  });
}
