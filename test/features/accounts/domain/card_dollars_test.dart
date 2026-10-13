import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/accounts/domain/card_dollars.dart';
import 'package:hishab/features/accounts/domain/credit_card.dart';

CreditCardStatus status(
  int balance, {
  int? limit,
  int? usdLimit,
  CardDollars dollars = CardDollars.none,
}) => CreditCardStatus(
  account: Account(
    id: 1,
    name: 'EBL',
    type: AccountType.creditCard,
    openingBalance: 0,
    includeInTotal: true,
    isArchived: false,
    creditLimit: limit,
    usdLimit: usdLimit,
  ),
  balance: balance,
  dollars: dollars,
);

void main() {
  group('CardDollars', () {
    test('owes what was spent less what was refunded and cleared', () {
      const dollars = CardDollars(spent: 30000, refunded: 2000, settled: 8000);

      expect(dollars.due, 20000);
    });

    test('never owes less than nothing', () {
      const dollars = CardDollars(spent: 5000, settled: 9000);

      expect(dollars.due, 0);
    });

    test('is unused until there is a dollar entry', () {
      expect(CardDollars.none.isUsed, isFalse);
      expect(const CardDollars(spent: 1).isUsed, isTrue);
      expect(const CardDollars(settled: 1).isUsed, isTrue);
    });

    test('turns dollars into taka at the latest rate', () {
      const dollars = CardDollars(lastRate: 122.5);

      expect(dollars.toPoisha(10000), 1225000); // $100 -> ৳1,225
      expect(CardDollars.none.toPoisha(10000), isNull);
    });
  });

  group('a card with a dollar part', () {
    // ৳120,000 limit of which $250 is in dollars; $100 was spent in dollars at
    // ৳122 (৳12,200) and ৳30,000 in taka.
    final card = status(
      -4220000,
      limit: 12000000,
      usdLimit: 25000,
      dollars: const CardDollars(spent: 10000, lastRate: 122),
    );

    test('has the dollars left of the dollar limit', () {
      expect(card.usdLeft, 15000);
    });

    test('has the taka left once the dollars are kept apart', () {
      // 120,000 - 42,200 = 77,800 left in all; $150 of it is dollars, which is
      // ৳18,300 at 122, so ৳59,500 is left in taka.
      expect(card.available, 7780000);
      expect(card.takaLeft, 5950000);
    });

    test('shows the dollar lines', () {
      expect(card.showsDollars, isTrue);
    });

    test('has no taka figure without a rate', () {
      final fresh = status(-3000000, limit: 12000000, usdLimit: 25000);

      expect(fresh.usdLeft, 25000);
      expect(fresh.takaLeft, isNull);
    });

    test('goes below zero when the dollar part is used up', () {
      final over = status(
        -4000000,
        limit: 12000000,
        usdLimit: 10000,
        dollars: const CardDollars(spent: 12000, lastRate: 120),
      );

      expect(over.usdLeft, -2000);
    });
  });

  group('a card without a dollar part', () {
    test('has no dollar figures', () {
      final card = status(-100000, limit: 500000);

      expect(card.usdLeft, isNull);
      expect(card.takaLeft, isNull);
      expect(card.showsDollars, isFalse);
    });

    test('still shows dollars once there is dollar spending', () {
      final card = status(
        -100000,
        dollars: const CardDollars(spent: 1000, lastRate: 120),
      );

      expect(card.showsDollars, isTrue);
      expect(card.usdLeft, isNull);
    });
  });

  group('creditCardsOf', () {
    test('gives each card its dollars', () {
      const account = Account(
        id: 7,
        name: 'EBL',
        type: AccountType.creditCard,
        openingBalance: 0,
        includeInTotal: true,
        isArchived: false,
      );
      final cards = creditCardsOf(
        const [AccountWithBalance(account: account, balance: -5000)],
        dollars: const {7: CardDollars(spent: 4000)},
      );

      expect(cards.single.dollars.spent, 4000);
    });
  });
}
