import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/domain/loan_insights.dart';

DebtItem _loan(
  int id, {
  int amount = 100000,
  int paid = 0,
  DateTime? due,
  DebtDirection direction = DebtDirection.lent,
}) => DebtItem(
  debt: Debt(
    id: id,
    person: 'P$id',
    direction: direction,
    amount: amount,
    openedOn: DateTime(2026, 9, 1),
    dueOn: due,
    note: '',
  ),
  paid: paid,
);

void main() {
  final today = DateTime(2026, 10, 11, 14);

  group('upcomingDues', () {
    test('lists open loans due soon, the soonest first, not the late', () {
      final result = upcomingDues([
        _loan(1, due: DateTime(2026, 10, 20)),
        _loan(2, due: DateTime(2026, 10, 11)),
        _loan(3, due: DateTime(2026, 10, 5)),
        _loan(4, due: DateTime(2026, 12, 30)),
        _loan(5),
        _loan(6, due: DateTime(2026, 10, 15), paid: 100000),
      ], today);

      expect(result.map((d) => d.item.debt.id), [2, 1]);
      expect(result.map((d) => d.daysLeft), [0, 9]);
    });

    test('takes only a few', () {
      final result = upcomingDues([
        for (var i = 1; i <= 6; i++) _loan(i, due: DateTime(2026, 10, 11 + i)),
      ], today);
      expect(result, hasLength(3));
      expect(result.first.item.debt.id, 1);
    });
  });

  test('netPosition counts card bills as money to give', () {
    final totals = debtTotals([
      _loan(1, amount: 500000),
      _loan(2, amount: 200000, direction: DebtDirection.borrowed),
    ], today);

    expect(netPosition(totals), 300000);
    expect(netPosition(totals, cardsOwed: 400000), -100000);
  });

  group('payoffPlan', () {
    test('spreads the amount and the last payment is what is left', () {
      final plan = payoffPlan(100000, 3)!;
      expect(plan.monthly, 33334);
      expect(plan.months, 3);
      expect(plan.last, 33332);
    });

    test('an even split has an even last payment', () {
      final plan = payoffPlan(120000, 6)!;
      expect(plan.monthly, 20000);
      expect(plan.last, 20000);
    });

    test('rounding up can finish a month early', () {
      // 10 over 4 months: 3 a month would be 3+3+3+1 = 4 months, but 100 over
      // 12 is 9 a month and ends in 12; check a case that shortens.
      final plan = payoffPlan(7, 6)!;
      expect(plan.monthly, 2);
      expect(plan.months, 4);
      expect(plan.last, 1);
    });

    test('nothing to pay off gives no plan', () {
      expect(payoffPlan(0, 3), isNull);
      expect(payoffPlan(1000, 0), isNull);
    });

    test('ends the month after the last payment starts counting', () {
      final plan = payoffPlan(120000, 6)!;
      expect(payoffEnd(plan, today), DateTime(2027, 4));
    });
  });

  group('searchAndSort', () {
    final items = [
      _loan(1, amount: 100000),
      _loan(2, amount: 500000),
      _loan(3, amount: 300000, paid: 300000),
      _loan(4, amount: 200000),
    ];

    test('biggest puts the most left first and settled last', () {
      final result = searchAndSort(
        items,
        query: '',
        sort: LoanSort.biggest,
        today: today,
      );
      expect(result.map((i) => i.debt.id), [2, 4, 1, 3]);
    });

    test('newest puts the latest first and settled last', () {
      final result = searchAndSort(
        items,
        query: '',
        sort: LoanSort.newest,
        today: today,
      );
      expect(result.map((i) => i.debt.id), [4, 2, 1, 3]);
    });

    test('a search keeps the names that match, whatever the case', () {
      final result = searchAndSort(
        items,
        query: ' p2 ',
        sort: LoanSort.due,
        today: today,
      );
      expect(result.map((i) => i.debt.id), [2]);
    });
  });
}
