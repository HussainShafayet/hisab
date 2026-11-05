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

    test('uses the account remembered for this kind of message', () {
      const sms = SmsEntry(
        kind: SmsKind.received,
        amount: 50000,
        source: 'id-trxid',
      );

      final unknown = planSms(sms, [cash, bkash, nagad]);
      expect(unknown.accountId, isNull);
      expect(unknown.accountSource, SmsAccountSource.unknown);

      final plan = planSms(
        sms,
        [cash, bkash, nagad],
        remembered: {'id-trxid': nagad.id},
      );
      expect(plan.accountId, nagad.id);
      expect(plan.accountSource, SmsAccountSource.remembered);
    });

    test('a named service wins over what was remembered', () {
      const sms = SmsEntry(
        kind: SmsKind.received,
        amount: 50000,
        provider: 'bkash',
        source: 'bkash',
      );

      final plan = planSms(
        sms,
        [cash, bkash, nagad],
        remembered: {'bkash': nagad.id},
      );
      expect(plan.accountId, bkash.id);
      expect(plan.accountSource, SmsAccountSource.named);
    });

    test('finds the bank account by the digits of the A/C', () {
      final city = account(5, 'City Bank 1234', AccountType.bank);
      final brac = account(6, 'Brac 9999', AccountType.bank);
      const sms = SmsEntry(
        kind: SmsKind.debited,
        amount: 80000,
        accountHint: '1234',
        bankLike: true,
      );

      final plan = planSms(sms, [cash, city, brac]);
      expect(plan.accountId, city.id);
      expect(plan.accountSource, SmsAccountSource.matched);
    });

    test('an ATM withdrawal moves money from the only bank to cash', () {
      const sms = SmsEntry(
        kind: SmsKind.cashOut,
        amount: 500000,
        bankLike: true,
      );

      final plan = planSms(sms, [cash, bkash, bank]);
      expect(plan.type, TransactionType.transfer);
      expect(plan.accountId, bank.id);
      expect(plan.toAccountId, cash.id);
      expect(plan.accountSource, SmsAccountSource.onlyOne);
    });
  });
}
