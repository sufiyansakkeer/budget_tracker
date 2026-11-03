import 'package:flutter_test/flutter_test.dart';
import 'package:monivo/core/currency/currency_formatter.dart';
import 'package:monivo/features/expenses/domain/entities/expense_entity.dart';
import 'package:monivo/features/pay_later/domain/entities/purchase_change_impact.dart';
import 'package:monivo/features/pay_later/presentation/widgets/purchase_impact_dialog.dart';

/// The "Never silent" copy (spec §5): where payment money goes.
void main() {
  String omr(double amount) => CurrencyFormatter.format(amount, code: 'OMR');

  ExpenseEntity purchase(String id, int day, {String? note}) => ExpenseEntity(
    id: id,
    budgetId: 'b1',
    amount: 2,
    categoryId: 'food',
    note: note,
    date: DateTime(2026, 11, day),
    time: DateTime(2026, 11, day, 13),
    createdAt: DateTime(2026, 11, day),
    updatedAt: DateTime(2026, 11, day),
  );

  PurchaseChangeImpact impact(
    List<(ExpenseEntity, double)> movesTo, {
    double paid = 2,
    double credit = 0,
    double? paidBefore,
  }) => PurchaseChangeImpact(
    paidOnIt: paid,
    paidBefore: paidBefore,
    movesTo: movesTo,
    becomesCredit: credit,
    currency: 'OMR',
  );

  String message(PurchaseChangeImpact i, {bool deleting = false}) =>
      PurchaseImpactDialog.message(i, deleting: deleting);

  test('money that moves names the purchase it goes towards', () {
    expect(
      message(impact([(purchase('l', 3, note: 'Lunch'), 2)])),
      '${omr(2)} already paid on this purchase will go towards "Lunch" on '
      '3 Nov.',
    );
  });

  test('money nothing owes stays as credit', () {
    expect(
      message(impact(const [], credit: 2)),
      '${omr(2)} already paid on this purchase will stay on the tab as '
      'credit.',
    );
  });

  test('a split says how much goes each way', () {
    expect(
      message(impact([(purchase('l', 3), 1.5)], paid: 2, credit: 0.5)),
      '${omr(2)} already paid on this purchase: ${omr(1.5)} will go towards '
      'your 3 Nov purchase, and ${omr(0.5)} will stay on the tab as credit.',
    );
  });

  test('several purchases are counted, and a delete says it is final', () {
    final text = message(
      impact([
        (purchase('a', 3, note: 'Lunch'), 1),
        (purchase('b', 4), 0.5),
        (purchase('c', 5), 0.5),
      ]),
      deleting: true,
    );
    expect(text, contains('"Lunch" on 3 Nov and 2 other purchases'));
    expect(text, endsWith("You can't undo this."));
  });

  group('identical labels (QA F2)', () {
    test('two same-day purchases without a note merge into one label', () {
      expect(
        message(impact([(purchase('a', 2), 1), (purchase('b', 2), 1)])),
        '${omr(2)} already paid on this purchase will go towards your 2 Nov '
        'purchases.',
      );
    });

    test('same note on the same day merges too', () {
      expect(
        message(
          impact([
            (purchase('a', 2, note: 'Lunch'), 1),
            (purchase('b', 2, note: 'Lunch'), 1),
          ]),
        ),
        '${omr(2)} already paid on this purchase will go towards your "Lunch" '
        'purchases on 2 Nov.',
      );
    });

    test('a merged label and one other read as two targets', () {
      expect(
        message(
          impact([
            (purchase('a', 2), 0.5),
            (purchase('b', 2), 0.5),
            (purchase('c', 3, note: 'Tea'), 1),
          ]),
        ),
        '${omr(2)} already paid on this purchase will go towards your 2 Nov '
        'purchases and "Tea" on 3 Nov.',
      );
    });

    test('three groups count the purchases outside the first', () {
      final text = message(
        impact([
          (purchase('a', 2), 0.5),
          (purchase('b', 2), 0.5),
          (purchase('c', 3), 0.5),
          (purchase('d', 4), 0.5),
        ]),
      );
      expect(text, contains('your 2 Nov purchases and 2 other purchases'));
    });

    test('never repeats a label', () {
      for (final count in [2, 3, 4]) {
        final text = message(
          impact([for (var i = 0; i < count; i++) (purchase('p$i', 2), 0.5)]),
        );
        expect(text, isNot(contains('purchase and your')), reason: text);
        expect(text, contains('your 2 Nov purchases'), reason: text);
      }
    });
  });

  group('edit down keeps part of what was paid (QA F3)', () {
    test('says how much is freed and moves and how much stays paid', () {
      expect(
        message(
          impact(
            [(purchase('a', 2), 0.75), (purchase('b', 2), 0.25)],
            paid: 1,
            paidBefore: 2,
          ),
        ),
        '${omr(2)} already paid on this purchase: ${omr(1)} stays paid, and '
        '${omr(1)} will go towards your 2 Nov purchases.',
      );
    });

    test('freed money nothing owes', () {
      expect(
        message(impact(const [], paid: 1, paidBefore: 2, credit: 1)),
        '${omr(2)} already paid on this purchase: ${omr(1)} stays paid, and '
        '${omr(1)} will stay on the tab as credit.',
      );
    });

    test('freed money split between a purchase and credit', () {
      expect(
        message(
          impact(
            [(purchase('a', 3), 0.5)],
            paid: 1.5,
            paidBefore: 2,
            credit: 1,
          ),
        ),
        '${omr(2)} already paid on this purchase: ${omr(0.5)} stays paid, '
        '${omr(0.5)} will go towards your 3 Nov purchase, and ${omr(1)} will '
        'stay on the tab as credit.',
      );
    });

    test('paidBefore defaults to the freed amount (all of it moves)', () {
      expect(impact(const [], paid: 2).paidBefore, 2);
    });
  });
}
