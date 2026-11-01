import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/features/budget/domain/usecases/manage_budget_usecase.dart';

/// Money kept aside and the savings goal follow one set of rules, in the use
/// case. They lived only in the budget form, and the "nothing free to spend"
/// warning summed in doubles.
void main() {
  group('validateSetAside', () {
    test('empty is fine', () {
      expect(ManageBudgetUseCase.validateSetAside(null, 1000), isNull);
    });

    test('negative is refused', () {
      expect(ManageBudgetUseCase.validateSetAside(-1, 1000), isNotNull);
    });

    test('more than the budget is refused', () {
      expect(ManageBudgetUseCase.validateSetAside(1001, 1000), isNotNull);
      expect(ManageBudgetUseCase.validateSetAside(1000, 1000), isNull);
    });
  });

  group('setAsideTakesAll', () {
    test('adds the two in the currency\'s units', () {
      // 138.7 + 0.2 is 138.89999… in doubles, just under the budget.
      expect(
        ManageBudgetUseCase.setAsideTakesAll(
          budgetAmount: 138.9,
          reserve: 138.7,
          savings: 0.2,
          currency: 'OMR',
        ),
        isTrue,
      );
    });

    test('something left is not all', () {
      expect(
        ManageBudgetUseCase.setAsideTakesAll(
          budgetAmount: 1000,
          reserve: 400,
          savings: 500,
          currency: 'INR',
        ),
        isFalse,
      );
    });

    test('nothing set aside is not all', () {
      expect(
        ManageBudgetUseCase.setAsideTakesAll(
          budgetAmount: 1000,
          currency: 'INR',
        ),
        isFalse,
      );
    });
  });
}
