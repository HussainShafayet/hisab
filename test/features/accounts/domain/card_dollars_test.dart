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

  group('a card with a taka limit and a dollar limit', () {
    // The bank shows ৳111,200 and $74. ৳20,000 is owed, of which $50 was spent
    // in dollars at ৳122 (৳6,100).
    final card = status(
      -2000000,
      limit: 11120000,
      usdLimit: 7400,
      dollars: const CardDollars(spent: 5000, lastRate: 122),
    );

    test('owes the dollars apart from the taka', () {
      expect(card.dollarsOwedAsTaka, 610000);
      expect(card.takaOwed, 1390000);
    });

    test('has what is left in each money', () {
      expect(card.takaLeft, 9730000);
      expect(card.usdLeft, 2400);
    });

    test('has what is left in all, with the dollars at the latest rate', () {
      expect(card.totalLeft, 10022800);
      expect(card.available, 10022800);
      expect(card.isOverLimit, isFalse);
    });

    test('shows the dollar lines', () {
      expect(card.hasDollarLimit, isTrue);
      expect(card.showsDollars, isTrue);
    });

    test('has no total before the first dollar expense, but both parts', () {
      final fresh = status(-300000, limit: 11120000, usdLimit: 7400);

      expect(fresh.takaOwed, 300000);
      expect(fresh.takaLeft, 10820000);
      expect(fresh.usdLeft, 7400);
      expect(fresh.totalLeft, isNull);
      expect(fresh.available, isNull);
    });

    test('passes the dollar limit on its own', () {
      final over = status(
        -1200000,
        limit: 11120000,
        usdLimit: 7400,
        dollars: const CardDollars(spent: 8000, lastRate: 122),
      );

      expect(over.usdLeft, -600);
      expect(over.isOverLimit, isTrue);
      expect(over.takaLeft, isNonNegative);
    });

    test('passes the taka limit on its own', () {
      final over = status(
        -12000000,
        limit: 11120000,
        usdLimit: 7400,
        dollars: const CardDollars(spent: 1000, lastRate: 122),
      );

      expect(over.takaLeft, isNegative);
      expect(over.usdLeft, 6400);
      expect(over.isOverLimit, isTrue);
    });

    test('counts money paid in beyond the bill towards the taka', () {
      final paid = status(30000, limit: 11120000, usdLimit: 7400);

      expect(paid.takaLeft, 11150000);
    });
  });

  group('a card with only a dollar limit', () {
    test('has dollars left but no taka figure', () {
      final card = status(
        -610000,
        usdLimit: 7400,
        dollars: const CardDollars(spent: 5000, lastRate: 122),
      );

      expect(card.takaLeft, isNull);
      expect(card.usdLeft, 2400);
      expect(card.totalLeft, isNull);
    });
  });

  group('a card without a dollar limit', () {
    test('has no dollar figures', () {
      final card = status(-100000, limit: 500000);

      expect(card.usdLeft, isNull);
      expect(card.hasDollarLimit, isFalse);
      expect(card.showsDollars, isFalse);
      expect(card.takaLeft, 400000);
      expect(card.available, 400000);
    });

    test('lets dollars use the one limit', () {
      final card = status(
        -100000,
        limit: 500000,
        dollars: const CardDollars(spent: 1000, lastRate: 120),
      );

      expect(card.showsDollars, isTrue);
      expect(card.takaOwed, 100000);
      expect(card.available, 400000);
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
