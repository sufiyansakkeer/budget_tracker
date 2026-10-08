import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/currency/currency_formatter.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/currency_excluded_summary.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/safe_to_spend_reason.dart';
import 'package:monivo/features/budget/domain/entities/safe_to_spend/unlinked_commitment_summary.dart';
import 'package:monivo/features/dashboard/presentation/widgets/safe_to_spend_copy.dart';

import 'safe_to_spend_fixtures.dart';

void main() {
  final e = safeToSpend();

  group('reason copy', () {
    test('maps every worded reason to its sentence', () {
      expect(
        SafeToSpendCopy.reason(const BillsUnavailableReason(), e),
        "Bills couldn't be loaded, so they aren't included. Today's amount "
        'may be too high.',
      );
      expect(
        SafeToSpendCopy.reason(const OverBudgetByReason(1500), e),
        "You've spent ₹1,500 more than this budget's amount.",
      );
      expect(
        SafeToSpendCopy.reason(const OvercommittedByReason(3000), e),
        "Bills and money set aside are ₹3,000 more than what's left in this "
        'budget.',
      );
      expect(
        SafeToSpendCopy.reason(const OverTodayReason(400), e),
        "You've spent ₹400 more than today's safe amount. Tomorrow's amount "
        'will be lower.',
      );
      expect(
        SafeToSpendCopy.reason(
          const AtRiskReason(averageDaily: 1000, deficit: 2200),
          e,
        ),
        'At your average so far (₹1,000 a day), this budget would end about '
        '₹2,200 short.',
      );
      expect(
        SafeToSpendCopy.reason(
          const AllowanceReducedReason(
            amount: 100,
            billsTotal: 2200,
            reserved: null,
            savings: null,
          ),
          e,
        ),
        "Today's amount is ₹100 lower because of bills and money set aside.",
      );
      expect(
        SafeToSpendCopy.reason(
          const BillsNotLinkedReason(count: 2, total: 1500),
          e,
        ),
        "2 upcoming bills (₹1,500) aren't linked to a budget, so nothing is "
        'set aside for them.',
      );
    });

    test('reasons shown elsewhere have no sentence', () {
      expect(SafeToSpendCopy.reason(const BillPaymentsTodayReason(5), e), null);
      expect(
        SafeToSpendCopy.reason(
          BillsDueReason(total: 5, count: 1, nextDue: DateTime(2026, 8, 20)),
          e,
        ),
        null,
      );
      expect(
        SafeToSpendCopy.reason(
          const ForecastInsufficientReason(daysNeeded: 1, hasAnyExpense: true),
          e,
        ),
        null,
      );
    });

    test('singular and plural', () {
      expect(
        SafeToSpendCopy.notLinked(
          const UnlinkedCommitmentSummary(count: 1, total: 500),
          'INR',
        ),
        "1 upcoming bill (₹500) isn't linked to a budget, so nothing is set "
        'aside for it.',
      );
      expect(
        SafeToSpendCopy.currencyExcluded(
          const CurrencyExcludedSummary(
            count: 1,
            totalsByCurrency: {'USD': 40},
          ),
          'INR',
        ),
        "1 linked bill in USD isn't included because this budget uses INR.",
      );
      expect(
        SafeToSpendCopy.currencyExcluded(
          const CurrencyExcludedSummary(
            count: 3,
            totalsByCurrency: {'USD': 40, 'AED': 10},
          ),
          'INR',
        ),
        "3 linked bills in AED, USD aren't included because this budget uses "
        'INR.',
      );
    });
  });

  group('hero explanation', () {
    test('takes the most important worded reason', () {
      final atRisk = runningStatusFixtures['budgetAtRisk']!();
      expect(
        SafeToSpendCopy.heroExplanation(atRisk),
        startsWith('At your average so far'),
      );
    });

    test('at risk only through money kept aside: says so, never that the '
        'budget ends short (review: contradicted "Projected left")', () {
      // 30,000 for Aug 1–31, on Aug 11: 9,000 spent before today (900 a
      // day), 5,000 kept aside. Projected left 2,100; margin −2,900.
      final entity = safeToSpend(
        amount: 30000,
        periodSpent: 9000,
        reserved: 5000,
        today: DateTime(2026, 8, 11),
      );
      expect(entity.forecast!.projectedEndBalance, 2100);
      expect(entity.forecast!.projectedMargin, -2900);
      expect(
        SafeToSpendCopy.heroExplanation(entity),
        "At your average so far (₹900 a day), you'd use about ₹2,900 of the "
        'money kept aside.',
      );

      final withSavings = safeToSpend(
        amount: 30000,
        periodSpent: 9000,
        reserved: 3000,
        savings: 2000,
        today: DateTime(2026, 8, 11),
      );
      expect(
        SafeToSpendCopy.heroExplanation(withSavings),
        "At your average so far (₹900 a day), you'd use about ₹2,900 of the "
        'money kept aside and your savings goal.',
      );

      final savingsOnly = safeToSpend(
        amount: 30000,
        periodSpent: 9000,
        savings: 5000,
        today: DateTime(2026, 8, 11),
      );
      expect(
        SafeToSpendCopy.heroExplanation(savingsOnly),
        "At your average so far (₹900 a day), you'd use about ₹2,900 of "
        'your savings goal.',
      );
    });

    test('overcommitted with spending today names the same amount as the '
        'breakdown\'s "short" (review: hero said ₹500, breakdown ₹800)', () {
      final entity = safeToSpend(
        amount: 22000,
        periodSpent: 21300,
        todaySpent: 300,
        commitments: [bill('rent', 1500, DateTime(2026, 8, 20))],
        today: DateTime(2026, 8, 11),
      );
      expect(entity.availableBalance, 700);
      expect(entity.spendableAtStartOfToday, -500);
      expect(SafeToSpendCopy.freeToSpendValue(entity), '₹800 short');
      expect(
        SafeToSpendCopy.heroExplanation(entity),
        "Bills and money set aside are ₹800 more than what's left in this "
        'budget.',
      );
    });

    test('a budget projected to end short names the forecast\'s shortfall, '
        'not the larger margin', () {
      // 18,000 spent before Aug 11 (1,800 a day): 30,000 − 18,000 − 37,800
      // = −25,800 projected; with 5,000 kept aside the margin is −30,800.
      final entity = safeToSpend(
        amount: 30000,
        periodSpent: 18000,
        reserved: 5000,
        today: DateTime(2026, 8, 11),
      );
      expect(entity.forecast!.projectedEndBalance, -25800);
      expect(entity.forecast!.projectedMargin, -30800);
      expect(
        SafeToSpendCopy.heroExplanation(entity),
        'At your average so far (₹1,800 a day), this budget would end about '
        '₹25,800 short.',
      );
    });

    test('leaves disclosures with their own notice card out of the line', () {
      final entity = safeToSpend(
        billsUnavailable: true,
        unlinked: const UnlinkedCommitmentSummary(count: 1, total: 500),
      );
      expect(SafeToSpendCopy.heroExplanation(entity), isNull);
    });

    test('nothing to explain on a plain on-track day', () {
      expect(SafeToSpendCopy.heroExplanation(safeToSpend()), isNull);
    });

    test('explains a daily amount below one minor unit', () {
      // ₹0.05 over 22 days: free money exists, but under ₹0.01 a day.
      final entity = safeToSpend(amount: 0.05);
      expect(
        SafeToSpendCopy.heroExplanation(entity),
        'Less than ₹0.01 a day is left in this budget.',
      );
    });
  });

  group('not running', () {
    test('not started names the start date and the bills set aside', () {
      final entity = safeToSpend(
        today: DateTime(2026, 7, 25),
        commitments: [bill('rent', 12000, DateTime(2026, 8, 5))],
      );
      expect(
        SafeToSpendCopy.notRunningTitle(entity),
        'This budget starts 1 Aug',
      );
      expect(
        SafeToSpendCopy.notRunningMessage(entity),
        'Starts 1 Aug. ₹12,000 in bills will be set aside from this budget.',
      );
    });

    test('ended reports the final balance either way', () {
      final left = safeToSpend(today: DateTime(2026, 9, 5), periodSpent: 20000);
      expect(
        SafeToSpendCopy.notRunningMessage(left),
        'Ended 31 Aug with ₹2,000 left.',
      );
      final over = safeToSpend(today: DateTime(2026, 9, 5), periodSpent: 23000);
      expect(
        SafeToSpendCopy.notRunningMessage(over),
        'Ended 31 Aug, ₹1,000 over.',
      );
    });
  });

  group('amounts', () {
    test('exact figures show the minor unit only when there is one', () {
      expect(SafeToSpendCopy.amount(1500, 'INR'), '₹1,500');
      expect(SafeToSpendCopy.amount(1500.5, 'INR'), '₹1,500.50');
      expect(SafeToSpendCopy.amount(-250, 'INR'), '−₹250');
      expect(
        SafeToSpendCopy.amount(7.6, 'OMR'),
        CurrencyFormatter.format(7.6, code: 'OMR', decimalDigits: 3),
      );
    });

    test('safe figures are floored', () {
      expect(SafeToSpendCopy.safeAmount(333.339, 'INR'), '₹333.33');
      expect(SafeToSpendCopy.safeAmount(999.999, 'INR'), '₹999.99');
    });
  });
}
