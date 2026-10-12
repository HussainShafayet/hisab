import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/debts/domain/debt.dart';

DebtItem item(
  int id, {
  int amount = 100000,
  int paid = 0,
  DebtDirection direction = DebtDirection.lent,
  DateTime? dueOn,
}) => DebtItem(
  debt: Debt(
    id: id,
    person: 'Person $id',
    direction: direction,
    amount: amount,
    openedOn: DateTime(2026, 10, 1),
    dueOn: dueOn,
    note: '',
  ),
  paid: paid,
);

// Sunday 11 October 2026.
final today = DateTime(2026, 10, 11, 14, 30);

void main() {
  group('DebtItem', () {
    test('has what is left, and is settled when nothing is', () {
      expect(item(1, paid: 25000).remaining, 75000);
      expect(item(1, paid: 25000).isSettled, isFalse);
      expect(item(1, paid: 100000).remaining, 0);
      expect(item(1, paid: 100000).isSettled, isTrue);
    });

    test('never has less than nothing left', () {
      expect(item(1, paid: 150000).remaining, 0);
    });

    test('shows how far it is paid, from 0 to 1', () {
      expect(item(1).progress, 0);
      expect(item(1, paid: 25000).progress, 0.25);
      expect(item(1, paid: 100000).progress, 1);
      expect(item(1, paid: 150000).progress, 1);
    });

    test('is overdue after its due day, not on it', () {
      expect(item(1, dueOn: DateTime(2026, 10, 10)).isOverdue(today), isTrue);
      expect(item(1, dueOn: DateTime(2026, 10, 11)).isOverdue(today), isFalse);
      expect(item(1, dueOn: DateTime(2026, 10, 12)).isOverdue(today), isFalse);
    });

    test('is not overdue without a due day or once it is settled', () {
      expect(item(1).isOverdue(today), isFalse);
      expect(
        item(1, paid: 100000, dueOn: DateTime(2026, 9, 1)).isOverdue(today),
        isFalse,
      );
    });

    test('counts the days to the due day, whatever the time of day', () {
      expect(item(1, dueOn: DateTime(2026, 10, 15)).daysUntilDue(today), 4);
      expect(item(1, dueOn: DateTime(2026, 10, 11, 23)).daysUntilDue(today), 0);
      expect(item(1, dueOn: DateTime(2026, 10, 10)).daysUntilDue(today), -1);
      expect(item(1).daysUntilDue(today), isNull);
    });
  });

  group('debtTotals', () {
    test('adds up what is left to get back and to pay back', () {
      final totals = debtTotals([
        item(1, amount: 50000, paid: 10000),
        item(2, amount: 20000),
        item(3, amount: 30000, direction: DebtDirection.borrowed),
        item(4, amount: 5000, paid: 1000, direction: DebtDirection.borrowed),
      ], today);

      expect(totals.toReceive, 60000);
      expect(totals.toPay, 34000);
    });

    test('leaves settled loans out', () {
      final totals = debtTotals([item(1, paid: 100000)], today);

      expect(totals.toReceive, 0);
      expect(totals.toPay, 0);
    });

    test('counts the loans that are overdue', () {
      final totals = debtTotals([
        item(1, dueOn: DateTime(2026, 10, 1)),
        item(2, dueOn: DateTime(2026, 9, 1), direction: DebtDirection.borrowed),
        item(3, dueOn: DateTime(2026, 10, 30)),
        item(4, dueOn: DateTime(2026, 9, 1), paid: 100000),
      ], today);

      expect(totals.overdueCount, 2);
    });

    test('is zero for no loans', () {
      final totals = debtTotals([], today);

      expect(totals.toReceive, 0);
      expect(totals.toPay, 0);
      expect(totals.overdueCount, 0);
    });
  });

  group('sortDebts', () {
    test('puts late loans first, then by due day, then those without one', () {
      final sorted = sortDebts([
        item(1),
        item(2, dueOn: DateTime(2026, 10, 20)),
        item(3, dueOn: DateTime(2026, 10, 1)),
        item(4, dueOn: DateTime(2026, 10, 15)),
        item(5, paid: 100000),
      ], today);

      expect(sorted.map((i) => i.debt.id), [3, 4, 2, 1, 5]);
    });

    test('puts the newest first among loans with no due day', () {
      final sorted = sortDebts([item(1), item(7), item(3)], today);

      expect(sorted.map((i) => i.debt.id), [7, 3, 1]);
    });

    test('puts settled loans last, newest first', () {
      final sorted = sortDebts([
        item(1, paid: 100000),
        item(2),
        item(3, paid: 100000),
      ], today);

      expect(sorted.map((i) => i.debt.id), [2, 3, 1]);
    });
  });
}
