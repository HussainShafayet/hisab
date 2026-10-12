import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/accounts/domain/credit_card.dart';

Account card({
  int id = 1,
  String name = 'Visa',
  int? limit,
  int? day,
  bool archived = false,
  AccountType type = AccountType.creditCard,
}) => Account(
  id: id,
  name: name,
  type: type,
  openingBalance: 0,
  includeInTotal: true,
  isArchived: archived,
  creditLimit: limit,
  billDueDay: day,
);

CreditCardStatus status(int balance, {int? limit, int? day}) =>
    CreditCardStatus(
      account: card(limit: limit, day: day),
      balance: balance,
    );

// Sunday 11 October 2026.
final today = DateTime(2026, 10, 11, 14, 30);

void main() {
  group('CreditCardStatus', () {
    test('owes what is below zero', () {
      expect(status(-125000).owed, 125000);
      expect(status(-125000).hasBill, isTrue);
      expect(status(-125000).credit, 0);
    });

    test('owes nothing at zero, and keeps money paid in beyond the bill', () {
      expect(status(0).owed, 0);
      expect(status(0).hasBill, isFalse);
      expect(status(30000).owed, 0);
      expect(status(30000).credit, 30000);
    });

    test('has what is left to spend from the limit', () {
      final s = status(-125000, limit: 500000);

      expect(s.available, 375000);
      expect(s.isOverLimit, isFalse);
      expect(s.usage, 0.25);
    });

    test('counts money paid in beyond the bill as more to spend', () {
      expect(status(20000, limit: 500000).available, 520000);
    });

    test('is over the limit when it owes more than the limit', () {
      final s = status(-600000, limit: 500000);

      expect(s.isOverLimit, isTrue);
      expect(s.available, -100000);
      expect(s.usage, 1);
    });

    test('has no figures that need a limit when there is none', () {
      final s = status(-125000);

      expect(s.limit, isNull);
      expect(s.available, isNull);
      expect(s.usage, isNull);
      expect(s.isOverLimit, isFalse);
    });

    test('knows when the bill is due', () {
      final s = status(-1000, day: 15);

      expect(s.nextDue(today), DateTime(2026, 10, 15));
      expect(s.daysUntilDue(today), 4);
      expect(status(-1000).nextDue(today), isNull);
      expect(status(-1000).daysUntilDue(today), isNull);
    });
  });

  group('nextBillDue', () {
    test('is later this month, or today', () {
      expect(nextBillDue(15, today), DateTime(2026, 10, 15));
      expect(nextBillDue(11, today), DateTime(2026, 10, 11));
    });

    test('is next month once the day has passed', () {
      expect(nextBillDue(5, today), DateTime(2026, 11, 5));
    });

    test('goes into the new year', () {
      expect(nextBillDue(5, DateTime(2026, 12, 20)), DateTime(2027, 1, 5));
    });

    test('is the last day of a month that is too short', () {
      expect(nextBillDue(31, DateTime(2026, 11, 2)), DateTime(2026, 11, 30));
      expect(nextBillDue(30, DateTime(2027, 2, 10)), DateTime(2027, 2, 28));
      expect(nextBillDue(31, DateTime(2027, 2, 28)), DateTime(2027, 2, 28));
      expect(nextBillDue(31, DateTime(2027, 3, 1)), DateTime(2027, 3, 31));
      // A leap year has a 29th.
      expect(nextBillDue(31, DateTime(2028, 2, 10)), DateTime(2028, 2, 29));
    });

    test('is nothing without a bill day', () {
      expect(nextBillDue(null, today), isNull);
    });
  });

  group('upcomingBillDues', () {
    test('lists the next few bill days', () {
      expect(upcomingBillDues(31, today, count: 3), [
        DateTime(2026, 10, 31),
        DateTime(2026, 11, 30),
        DateTime(2026, 12, 31),
      ]);
    });

    test('gives two by default, and none without a bill day', () {
      expect(upcomingBillDues(15, today), [
        DateTime(2026, 10, 15),
        DateTime(2026, 11, 15),
      ]);
      expect(upcomingBillDues(null, today), isEmpty);
    });
  });

  group('creditCardsOf', () {
    AccountWithBalance of(Account account, int balance) =>
        AccountWithBalance(account: account, balance: balance);

    test('keeps the open credit cards, the ones that owe most first', () {
      final cards = creditCardsOf([
        of(card(id: 1, name: 'Small'), -1000),
        of(card(id: 2, name: 'Big'), -90000),
        of(card(id: 3, name: 'Old', archived: true), -5000),
        of(card(id: 4, name: 'Debit', type: AccountType.card), -7000),
        of(card(id: 5, name: 'Cash', type: AccountType.cash), -8000),
      ]);

      expect(cards.map((c) => c.account.name), ['Big', 'Small']);
    });

    test('puts cards that owe the same in name order', () {
      final cards = creditCardsOf([
        of(card(id: 1, name: 'b card'), 0),
        of(card(id: 2, name: 'A card'), 0),
      ]);

      expect(cards.map((c) => c.account.name), ['A card', 'b card']);
    });

    test('adds up what is owed on all of them', () {
      final cards = creditCardsOf([
        of(card(id: 1), -1000),
        of(card(id: 2, name: 'Two'), -2500),
        of(card(id: 3, name: 'Three'), 400),
      ]);

      expect(totalOwed(cards), 3500);
    });
  });
}
