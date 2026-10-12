import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/debts/domain/debt.dart';

DebtItem item(
  int id, {
  String? person,
  int amount = 100000,
  int paid = 0,
  DebtDirection direction = DebtDirection.lent,
  DateTime? dueOn,
}) => DebtItem(
  debt: Debt(
    id: id,
    person: person ?? 'Person $id',
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

  group('personKey', () {
    test('ignores case and spaces around the name', () {
      expect(personKey('  Rahim '), personKey('rahim'));
      expect(personKey('Rahim'), isNot(personKey('Rahim Uddin')));
    });
  });

  group('groupByPerson', () {
    test('puts the loans of one person together, whatever the spelling', () {
      final people = groupByPerson([
        item(1, person: 'Rahim', amount: 100000),
        item(
          2,
          person: 'rahim',
          amount: 30000,
          direction: DebtDirection.borrowed,
        ),
        item(3, person: 'Karim'),
      ], today);

      expect(people, hasLength(2));
      final rahim = people.firstWhere((p) => personKey(p.name) == 'rahim');
      expect(rahim.items, hasLength(2));
      // The newest loan has the spelling.
      expect(rahim.name, 'rahim');
    });

    test('works out what each owes the other, and the difference', () {
      final rahim = groupByPerson([
        item(1, person: 'Rahim', amount: 100000, paid: 20000),
        item(
          2,
          person: 'Rahim',
          amount: 30000,
          direction: DebtDirection.borrowed,
        ),
      ], today).single;

      expect(rahim.toReceive, 80000);
      expect(rahim.toPay, 30000);
      expect(rahim.net, 50000);
      expect(rahim.isSettled, isFalse);
    });

    test('is negative when I owe more than I am owed', () {
      final rahim = groupByPerson([
        item(1, person: 'Rahim', amount: 10000),
        item(
          2,
          person: 'Rahim',
          amount: 30000,
          direction: DebtDirection.borrowed,
        ),
      ], today).single;

      expect(rahim.net, -20000);
    });

    test('does not count settled loans', () {
      final rahim = groupByPerson([
        item(1, person: 'Rahim', amount: 100000, paid: 100000),
        item(2, person: 'Rahim', amount: 5000),
      ], today).single;

      expect(rahim.toReceive, 5000);
      expect(rahim.isSettled, isFalse);
    });

    test('is settled when everything with the person is paid', () {
      final rahim = groupByPerson([
        item(1, person: 'Rahim', amount: 100000, paid: 100000),
      ], today).single;

      expect(rahim.isSettled, isTrue);
      expect(rahim.net, 0);
    });

    test('counts the late loans of a person', () {
      final rahim = groupByPerson([
        item(1, person: 'Rahim', dueOn: DateTime(2026, 10, 1)),
        item(2, person: 'Rahim', dueOn: DateTime(2026, 12, 1)),
      ], today).single;

      expect(rahim.overdueCount(today), 1);
    });

    test('lists late people first, then the biggest difference, then paid', () {
      final people = groupByPerson([
        item(1, person: 'Small', amount: 1000),
        item(2, person: 'Big', amount: 90000),
        item(3, person: 'Late', amount: 500, dueOn: DateTime(2026, 10, 1)),
        item(4, person: 'Done', amount: 70000, paid: 70000),
        item(5, person: 'Alpha Done', amount: 100, paid: 100),
      ], today);

      expect(people.map((p) => p.name), [
        'Late',
        'Big',
        'Small',
        'Alpha Done',
        'Done',
      ]);
    });
  });

  group('debtsGoing', () {
    test('keeps one direction, late ones first', () {
      final list = debtsGoing(
        [
          item(1, direction: DebtDirection.borrowed),
          item(2),
          item(3, dueOn: DateTime(2026, 10, 1)),
          item(4),
        ],
        DebtDirection.lent,
        today,
      );

      expect(list.map((i) => i.debt.id), [3, 4, 2]);
    });
  });

  group('upcomingDebtReminders', () {
    test('plans the day before and the due day', () {
      final list = upcomingDebtReminders([
        item(1, dueOn: DateTime(2026, 10, 20)),
      ], today);

      expect(list.map((r) => r.day), [
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 20),
      ]);
      expect(list.map((r) => r.dayBefore), [true, false]);
    });

    test('plans only the due day when the day before has passed', () {
      final list = upcomingDebtReminders([
        item(1, dueOn: DateTime(2026, 10, 11)),
      ], today);

      expect(list.map((r) => r.dayBefore), [false]);
    });

    test('plans the heads-up for tomorrow today', () {
      final list = upcomingDebtReminders([
        item(1, dueOn: DateTime(2026, 10, 12)),
      ], today);

      expect(list.map((r) => r.day), [
        DateTime(2026, 10, 11),
        DateTime(2026, 10, 12),
      ]);
    });

    test('leaves out late, settled and undated loans', () {
      final list = upcomingDebtReminders([
        item(1, dueOn: DateTime(2026, 10, 10)),
        item(2, paid: 100000, dueOn: DateTime(2026, 10, 20)),
        item(3),
      ], today);

      expect(list, isEmpty);
    });

    test('is in date order', () {
      final list = upcomingDebtReminders([
        item(1, dueOn: DateTime(2026, 11, 20)),
        item(2, dueOn: DateTime(2026, 10, 20)),
      ], today);

      expect(list.map((r) => r.item.debt.id), [2, 2, 1, 1]);
    });
  });

  group('setting off', () {
    PersonDebts rahim(List<DebtItem> items) =>
        groupByPerson(items, today).single;

    List<(int, int)> plan(List<DebtItem> items) => [
      for (final step in planSetOff(rahim(items))) (step.debtId, step.amount),
    ];

    test('takes the smaller of the two sides off both', () {
      final person = rahim([
        item(1, person: 'Rahim', amount: 100000),
        item(
          2,
          person: 'Rahim',
          amount: 30000,
          direction: DebtDirection.borrowed,
        ),
      ]);

      expect(person.setOffAmount, 30000);
      expect(
        plan([
          item(1, person: 'Rahim', amount: 100000),
          item(
            2,
            person: 'Rahim',
            amount: 30000,
            direction: DebtDirection.borrowed,
          ),
        ]),
        [(1, 30000), (2, 30000)],
      );
    });

    test('works when I owe more than I am owed', () {
      expect(
        plan([
          item(1, person: 'Rahim', amount: 10000),
          item(
            2,
            person: 'Rahim',
            amount: 40000,
            direction: DebtDirection.borrowed,
          ),
        ]),
        [(1, 10000), (2, 10000)],
      );
    });

    test('spreads over several loans, the earliest due first', () {
      expect(
        plan([
          item(1, person: 'Rahim', amount: 20000, dueOn: DateTime(2026, 12, 1)),
          item(2, person: 'Rahim', amount: 20000, dueOn: DateTime(2026, 11, 1)),
          item(
            3,
            person: 'Rahim',
            amount: 30000,
            direction: DebtDirection.borrowed,
          ),
        ]),
        [(2, 20000), (1, 10000), (3, 30000)],
      );
    });

    test('uses what is left, not the whole amount', () {
      expect(
        plan([
          item(1, person: 'Rahim', amount: 100000, paid: 90000),
          item(
            2,
            person: 'Rahim',
            amount: 50000,
            direction: DebtDirection.borrowed,
          ),
        ]),
        [(1, 10000), (2, 10000)],
      );
    });

    test('has nothing to do when the money goes only one way', () {
      final only = rahim([item(1, person: 'Rahim')]);

      expect(only.setOffAmount, 0);
      expect(planSetOff(only), isEmpty);
    });

    test('leaves paid loans out', () {
      final person = rahim([
        item(1, person: 'Rahim', amount: 5000, paid: 5000),
        item(
          2,
          person: 'Rahim',
          amount: 30000,
          direction: DebtDirection.borrowed,
        ),
      ]);

      expect(planSetOff(person), isEmpty);
    });
  });
}
