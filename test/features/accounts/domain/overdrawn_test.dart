import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/accounts/domain/overdrawn.dart';

AccountWithBalance item(
  int balance, {
  int id = 1,
  AccountType type = AccountType.cash,
  bool archived = false,
}) => AccountWithBalance(
  account: Account(
    id: id,
    name: 'Account $id',
    type: type,
    openingBalance: 0,
    includeInTotal: true,
    isArchived: archived,
  ),
  balance: balance,
);

void main() {
  group('isOverdrawn', () {
    test('is true below zero and false at zero or above', () {
      expect(isOverdrawn(item(-1)), isTrue);
      expect(isOverdrawn(item(0)), isFalse);
      expect(isOverdrawn(item(5000)), isFalse);
    });

    test('leaves out a credit card, which owes by design', () {
      expect(isOverdrawn(item(-50000, type: AccountType.creditCard)), isFalse);
    });

    test('leaves out an archived account', () {
      expect(isOverdrawn(item(-50000, archived: true)), isFalse);
    });

    test('counts a bank or a mobile wallet like cash', () {
      expect(isOverdrawn(item(-100, type: AccountType.bank)), isTrue);
      expect(isOverdrawn(item(-100, type: AccountType.mobileBanking)), isTrue);
    });
  });

  group('overdrawnAccounts', () {
    test('lists the accounts below zero, the deepest first', () {
      final list = overdrawnAccounts([
        item(-100, id: 1),
        item(2000, id: 2),
        item(-900, id: 3),
        item(-50000, id: 4, type: AccountType.creditCard),
      ]);

      expect(list.map((i) => i.account.id), [3, 1]);
    });

    test('is empty when every account is fine', () {
      expect(overdrawnAccounts([item(0), item(100, id: 2)]), isEmpty);
      expect(overdrawnAccounts(const []), isEmpty);
    });
  });
}
