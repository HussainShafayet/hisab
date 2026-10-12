import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/transactions/domain/balance_preview.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

void main() {
  const cash = 1;
  const bkash = 2;
  const bank = 3;

  group('TransactionEffect', () {
    test('an income adds to its account only', () {
      const effect = TransactionEffect(
        type: TransactionType.income,
        amount: 5000,
        accountId: cash,
      );

      expect(effect.changeFor(cash), 5000);
      expect(effect.changeFor(bkash), 0);
    });

    test('an expense takes from its account only', () {
      const effect = TransactionEffect(
        type: TransactionType.expense,
        amount: 1200,
        accountId: cash,
      );

      expect(effect.changeFor(cash), -1200);
      expect(effect.changeFor(bkash), 0);
    });

    test('a transfer takes from one account and adds to the other', () {
      const effect = TransactionEffect(
        type: TransactionType.transfer,
        amount: 100000,
        accountId: cash,
        toAccountId: bkash,
      );

      expect(effect.changeFor(cash), -100000);
      expect(effect.changeFor(bkash), 100000);
      expect(effect.changeFor(bank), 0);
    });

    test('the fee of a transfer comes off the account the money leaves', () {
      const effect = TransactionEffect(
        type: TransactionType.transfer,
        amount: 100000,
        accountId: cash,
        toAccountId: bkash,
        fee: 1500,
      );

      expect(effect.changeFor(cash), -101500);
      expect(effect.changeFor(bkash), 100000);
    });

    test('a transfer with no destination yet still takes from its account', () {
      const effect = TransactionEffect(
        type: TransactionType.transfer,
        amount: 100000,
        accountId: cash,
      );

      expect(effect.changeFor(cash), -100000);
      expect(effect.changeFor(bkash), 0);
    });
  });

  group('projectedBalance', () {
    const expense = TransactionEffect(
      type: TransactionType.expense,
      amount: 120000,
      accountId: cash,
    );

    test('is the balance after the new transaction', () {
      expect(
        projectedBalance(current: 500000, account: cash, after: expense),
        380000,
      );
    });

    test('can go below zero', () {
      expect(
        projectedBalance(current: 50000, account: cash, after: expense),
        -70000,
      );
    });

    test('is the balance now when nothing is entered yet', () {
      expect(
        projectedBalance(current: 500000, account: cash, after: null),
        500000,
      );
    });

    test('leaves an account the transaction does not touch alone', () {
      expect(
        projectedBalance(current: 500000, account: bkash, after: expense),
        500000,
      );
    });

    test('takes back the transaction being edited first', () {
      // The balance of 380,000 already has the old expense of 1,200 taka
      // taken off. Changing it to 2,000 taka leaves 300,000, not 180,000.
      const edited = TransactionEffect(
        type: TransactionType.expense,
        amount: 200000,
        accountId: cash,
      );

      expect(
        projectedBalance(
          current: 380000,
          account: cash,
          after: edited,
          before: expense,
        ),
        300000,
      );
    });

    test('an edit that moves a transaction to another account', () {
      const moved = TransactionEffect(
        type: TransactionType.expense,
        amount: 120000,
        accountId: bkash,
      );

      // Cash gets its money back; bKash pays instead.
      expect(
        projectedBalance(
          current: 380000,
          account: cash,
          after: moved,
          before: expense,
        ),
        500000,
      );
      expect(
        projectedBalance(
          current: 0,
          account: bkash,
          after: moved,
          before: expense,
        ),
        -120000,
      );
    });

    test('an edit that turns an expense into an income', () {
      const income = TransactionEffect(
        type: TransactionType.income,
        amount: 120000,
        accountId: cash,
      );

      expect(
        projectedBalance(
          current: 380000,
          account: cash,
          after: income,
          before: expense,
        ),
        620000,
      );
    });
  });
}
