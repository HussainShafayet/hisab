import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/transactions/domain/sms_entry.dart';
import 'package:hishab/features/transactions/domain/sms_plan.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

Account account(int id, String name, AccountType type) => Account(
  id: id,
  name: name,
  type: type,
  openingBalance: 0,
  includeInTotal: true,
  isArchived: false,
);

final cash = account(1, 'Cash', AccountType.cash);
final bkash = account(2, 'bKash', AccountType.mobileBanking);
final nagad = account(3, 'Nagad', AccountType.mobileBanking);
final bank = account(4, 'Bank', AccountType.bank);

void main() {
  group('planSms', () {
    test('a cash out is a transfer to cash, with its fee', () {
      final plan = planSms(
        const SmsEntry(
          kind: SmsKind.cashOut,
          amount: 50000,
          fee: 925,
          provider: 'bkash',
        ),
        [cash, bkash, nagad],
      );

      expect(plan.type, TransactionType.transfer);
      expect(plan.accountId, bkash.id);
      expect(plan.toAccountId, cash.id);
      expect(plan.amount, 50000);
      expect(plan.transferFee, 925);
      expect(plan.balanceAccountId, bkash.id);
      expect(plan.balanceChange, -50925);
    });

    test('a cash in is a transfer from cash', () {
      final plan = planSms(
        const SmsEntry(kind: SmsKind.cashIn, amount: 100000, provider: 'nagad'),
        [cash, bkash, nagad],
      );

      expect(plan.type, TransactionType.transfer);
      expect(plan.accountId, cash.id);
      expect(plan.toAccountId, nagad.id);
      expect(plan.balanceChange, 100000);
    });

    test('a cash out without a cash account is spending with the fee', () {
      final plan = planSms(
        const SmsEntry(
          kind: SmsKind.cashOut,
          amount: 50000,
          fee: 925,
          provider: 'bkash',
        ),
        [bkash],
      );

      expect(plan.type, TransactionType.expense);
      expect(plan.amount, 50925);
      expect(plan.accountId, bkash.id);
    });

    test('money received is income in the service account', () {
      final plan = planSms(
        const SmsEntry(
          kind: SmsKind.received,
          amount: 30000,
          provider: 'bkash',
        ),
        [cash, bkash, nagad],
      );

      expect(plan.type, TransactionType.income);
      expect(plan.accountId, bkash.id);
      expect(plan.balanceChange, 30000);
    });

    test('a message with no service goes to the only mobile account', () {
      final plan = planSms(
        const SmsEntry(kind: SmsKind.payment, amount: 12000),
        [cash, bkash, bank],
      );

      expect(plan.type, TransactionType.expense);
      expect(plan.accountId, bkash.id);
    });

    test('with two mobile accounts and no service the form keeps its own', () {
      final plan = planSms(
        const SmsEntry(kind: SmsKind.payment, amount: 12000),
        [cash, bkash, nagad],
        currentAccountId: cash.id,
      );

      expect(plan.accountId, isNull);
      expect(plan.balanceAccountId, cash.id);
    });

    test('a bank debit goes to the only bank account', () {
      final plan = planSms(
        const SmsEntry(kind: SmsKind.debited, amount: 120000),
        [cash, bkash, bank],
      );

      expect(plan.accountId, bank.id);
      expect(plan.balanceChange, -120000);
    });
  });
}
