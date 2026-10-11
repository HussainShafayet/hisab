import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/account_balance.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

AccountWithBalance item(
  int balance, {
  bool includeInTotal = true,
  bool isArchived = false,
}) => AccountWithBalance(
  account: Account(
    id: 1,
    name: 'Test',
    type: AccountType.cash,
    openingBalance: 0,
    includeInTotal: includeInTotal,
    isArchived: isArchived,
  ),
  balance: balance,
);

void main() {
  group('calculateAccountBalance', () {
    test('is the opening balance when nothing happened', () {
      expect(
        calculateAccountBalance(
          openingBalance: 500000,
          flows: const AccountFlows(),
        ),
        500000,
      );
    });

    test('adds income and subtracts expense', () {
      expect(
        calculateAccountBalance(
          openingBalance: 100000,
          flows: const AccountFlows(income: 300000, expense: 120000),
        ),
        280000,
      );
    });

    test('subtracts transfers out and adds transfers in', () {
      expect(
        calculateAccountBalance(
          openingBalance: 0,
          flows: const AccountFlows(transferOut: 40000, transferIn: 15000),
        ),
        -25000,
      );
    });

    test('combines everything', () {
      expect(
        calculateAccountBalance(
          openingBalance: 1000,
          flows: const AccountFlows(
            income: 500,
            expense: 200,
            transferOut: 100,
            transferIn: 50,
          ),
        ),
        1000 + 500 - 200 - 100 + 50,
      );
    });

    test('can go negative, e.g. a card or a negative opening balance', () {
      expect(
        calculateAccountBalance(
          openingBalance: -50000,
          flows: const AccountFlows(expense: 10000),
        ),
        -60000,
      );
    });
  });

  group('calculateTotalBalance', () {
    test('is zero for no accounts', () {
      expect(calculateTotalBalance([]), 0);
    });

    test('sums active accounts that are included', () {
      expect(calculateTotalBalance([item(100), item(250), item(-50)]), 300);
    });

    test('leaves out accounts excluded from the total', () {
      expect(
        calculateTotalBalance([item(100), item(900, includeInTotal: false)]),
        100,
      );
    });

    test('leaves out archived accounts', () {
      expect(
        calculateTotalBalance([item(100), item(900, isArchived: true)]),
        100,
      );
    });
  });

  group('calculateBalanceAdjustment', () {
    test('is null when the balance already matches', () {
      expect(calculateBalanceAdjustment(current: 5000, target: 5000), isNull);
    });

    test('is income when the real balance is higher', () {
      final adjustment = calculateBalanceAdjustment(
        current: 5000,
        target: 7550,
      )!;
      expect(adjustment.type, TransactionType.income);
      expect(adjustment.amount, 2550);
    });

    test('is expense when the real balance is lower', () {
      final adjustment = calculateBalanceAdjustment(current: 5000, target: 1)!;
      expect(adjustment.type, TransactionType.expense);
      expect(adjustment.amount, 4999);
    });

    test('works across zero', () {
      final adjustment = calculateBalanceAdjustment(
        current: -1000,
        target: 500,
      )!;
      expect(adjustment.type, TransactionType.income);
      expect(adjustment.amount, 1500);
    });
  });
}
