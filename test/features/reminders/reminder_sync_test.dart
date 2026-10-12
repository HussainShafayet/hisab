import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/reminders/reminder_sync.dart';

// Sunday 11 October 2026.
final now = DateTime(2026, 10, 11, 14, 30);

DebtItem loan(
  int id, {
  String person = 'Rahim',
  DebtDirection direction = DebtDirection.lent,
  int amount = 60000,
  int paid = 0,
  DateTime? dueOn,
}) => DebtItem(
  debt: Debt(
    id: id,
    person: person,
    direction: direction,
    amount: amount,
    openedOn: DateTime(2026, 10, 1),
    dueOn: dueOn,
    note: '',
  ),
  paid: paid,
);

Account card({
  int id = 3,
  String name = 'Visa',
  int? day = 15,
  bool archived = false,
  AccountType type = AccountType.creditCard,
}) => Account(
  id: id,
  name: name,
  type: type,
  openingBalance: 0,
  includeInTotal: true,
  isArchived: archived,
  billDueDay: day,
);

void main() {
  group('loan reminders', () {
    test('come the day before and on the day, at 9 am', () {
      final list = loanRemindersFor([
        loan(7, dueOn: DateTime(2026, 10, 20)),
      ], now);

      expect(list, hasLength(2));
      expect(list[0].when, DateTime(2026, 10, 19, 9));
      expect(list[0].title, 'Loan due tomorrow');
      expect(list[1].when, DateTime(2026, 10, 20, 9));
      expect(list[1].title, 'Loan due today');
      expect(list[1].body, 'Rahim should pay you ৳600.00.');
    });

    test('name what is left, and which way the money goes', () {
      final list = loanRemindersFor([
        loan(
          8,
          person: 'Karim',
          direction: DebtDirection.borrowed,
          amount: 50000,
          paid: 20000,
          dueOn: DateTime(2026, 10, 20),
        ),
      ], now);

      expect(list.last.body, 'You should pay Karim ৳300.00.');
    });

    test('skip the heads-up when the day before has passed', () {
      final list = loanRemindersFor([
        loan(7, dueOn: DateTime(2026, 10, 11)),
      ], now);

      expect(list.map((r) => r.title), ['Loan due today']);
    });

    test('skip loans that are late, settled or have no due day', () {
      final list = loanRemindersFor([
        loan(1, dueOn: DateTime(2026, 10, 1)),
        loan(2, paid: 60000, dueOn: DateTime(2026, 10, 20)),
        loan(3),
      ], now);

      expect(list, isEmpty);
    });

    test('have their own ids, two for each loan', () {
      final list = loanRemindersFor([
        loan(7, dueOn: DateTime(2026, 10, 20)),
        loan(8, dueOn: DateTime(2026, 10, 21)),
      ], now);

      final ids = list.map((r) => r.id).toList();
      expect(ids.toSet(), hasLength(4));
      expect(ids, everyElement(greaterThanOrEqualTo(100000000)));
    });

    test('are limited, so the phone is not flooded', () {
      final list = loanRemindersFor([
        for (var i = 1; i <= 100; i++) loan(i, dueOn: DateTime(2026, 12, 1)),
      ], now);

      expect(list, hasLength(60));
    });
  });

  group('credit card reminders', () {
    test('come for the next two bill days, the day before and the day', () {
      final list = cardRemindersFor([card()], now);

      expect(list.map((r) => r.when), [
        DateTime(2026, 10, 14, 9),
        DateTime(2026, 10, 15, 9),
        DateTime(2026, 11, 14, 9),
        DateTime(2026, 11, 15, 9),
      ]);
      expect(list.map((r) => r.title), [
        'Credit card bill due tomorrow',
        'Credit card bill due today',
        'Credit card bill due tomorrow',
        'Credit card bill due today',
      ]);
      expect(list.first.body, 'Pay your Visa bill on time to avoid charges.');
    });

    test('do not name an amount, which changes with every purchase', () {
      final list = cardRemindersFor([card()], now);

      expect(list.any((r) => r.body.contains('৳')), isFalse);
    });

    test('have their own ids, four for each card', () {
      final list = cardRemindersFor([card(id: 3), card(id: 4, name: 'B')], now);

      final ids = list.map((r) => r.id).toList();
      expect(ids.toSet(), hasLength(8));
      expect(ids, everyElement(greaterThanOrEqualTo(200000000)));
    });

    test(
      'skip cards without a bill day, archived cards and other accounts',
      () {
        final list = cardRemindersFor([
          card(day: null),
          card(id: 4, archived: true),
          card(id: 5, type: AccountType.card),
        ], now);

        expect(list, isEmpty);
      },
    );
  });
}
