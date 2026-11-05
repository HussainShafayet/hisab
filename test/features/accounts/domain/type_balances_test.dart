import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/accounts/domain/type_balances.dart';

Account _account(int id, AccountType type, {bool archived = false}) => Account(
  id: id,
  name: 'A$id',
  type: type,
  openingBalance: 0,
  includeInTotal: true,
  isArchived: archived,
);

void main() {
  test('adds up the accounts of each kind, in the order of the kinds', () {
    final result = balancesByType(
      [
        _account(1, AccountType.bank),
        _account(2, AccountType.cash),
        _account(3, AccountType.bank),
        _account(4, AccountType.creditCard),
      ],
      {1: 100000, 2: 50000, 3: 25000, 4: -300000},
    );

    expect(result.map((r) => r.type), [
      AccountType.cash,
      AccountType.bank,
      AccountType.creditCard,
    ]);
    expect(result.map((r) => r.total), [50000, 125000, -300000]);
    expect(result[1].count, 2);
  });

  test('leaves out archived accounts and ones with no balance yet', () {
    final result = balancesByType(
      [
        _account(1, AccountType.cash, archived: true),
        _account(2, AccountType.bank),
      ],
      {1: 100, 3: 5},
    );
    expect(result, isEmpty);
  });
}
