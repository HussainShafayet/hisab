import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/transactions/domain/sms_entry.dart';

void main() {
  group('parseSms', () {
    test('reads money received on bKash', () {
      final sms = parseSms(
        'You have received Tk 500.00 from 01712345678. Fee Tk 0.00. '
        'Balance Tk 1,234.56. TrxID 9GH7K2L1 at 24/10/2026 14:30',
      )!;

      expect(sms.kind, SmsKind.received);
      expect(sms.isIncome, isTrue);
      expect(sms.amount, 50000);
      expect(sms.fee, 0);
      expect(sms.balance, 123456);
      expect(sms.trxId, '9GH7K2L1');
      expect(sms.counterparty, '01712345678');
      expect(sms.date, DateTime(2026, 10, 24));
    });

    test('reads a cash out with its fee', () {
      final sms = parseSms(
        'Cash Out Tk 500.00 to 01712345678 successful. Fee Tk 9.25. '
        'Balance Tk 700.00. TrxID 9GH7K2L2 at 24/10/2026 15:01',
      )!;

      expect(sms.kind, SmsKind.cashOut);
      expect(sms.isIncome, isFalse);
      expect(sms.amount, 50000);
      expect(sms.fee, 925);
      expect(sms.balance, 70000);
    });

    test('reads the layout with labels and colons', () {
      final sms = parseSms(
        'Cash Out Successful. Amount: Tk 1,000.00 Fee: Tk 18.50 '
        'Balance: Tk 2,310.25 TrxID: 7ABC12DEF Date: 24/10/2026 14:30 Nagad',
      )!;

      expect(sms.kind, SmsKind.cashOut);
      expect(sms.amount, 100000);
      expect(sms.fee, 1850);
      expect(sms.balance, 231025);
      expect(sms.trxId, '7ABC12DEF');
      expect(sms.provider, 'nagad');
    });

    test('reads a payment to a shop', () {
      final sms = parseSms(
        'Payment Tk 120.00 to Shwapno successful. Fee Tk 0.00. '
        'Balance Tk 80.00. TrxID 9GH7K2L3 at 24/10/2026 16:00',
      )!;

      expect(sms.kind, SmsKind.payment);
      expect(sms.amount, 12000);
      expect(sms.counterparty, 'Shwapno');
    });

    test('reads a recharge', () {
      final sms = parseSms(
        'Mobile Recharge Tk 50.00 to 01812345678 successful. Fee Tk 0.00. '
        'Balance Tk 650.00. TrxID 9GH7K2L4 at 24/10/2026 16:10',
      )!;

      expect(sms.kind, SmsKind.recharge);
      expect(sms.amount, 5000);
    });

    test('reads a bank debit with a written month', () {
      final sms = parseSms(
        'Your A/C XXXX1234 has been debited by BDT 1,200.00 on 24-OCT-26. '
        'Avail Bal: BDT 5,000.00',
      )!;

      expect(sms.kind, SmsKind.debited);
      expect(sms.amount, 120000);
      expect(sms.balance, 500000);
      expect(sms.date, DateTime(2026, 10, 24));
      expect(sms.provider, isNull);
    });

    test('says received before sent when a message has both', () {
      final sms = parseSms(
        'Money Received. Amount: Tk 300.00 Sender: 01912345678 Ref: sent '
        'Balance: Tk 900.00 TrxID: 7XYZ99AA Date: 24/10/2026 10:00',
      )!;

      expect(sms.kind, SmsKind.received);
      expect(sms.amount, 30000);
    });

    test('is null for text that is not about money moving', () {
      expect(parseSms('hello'), isNull);
      expect(parseSms('Your balance is Tk 500.00'), isNull);
      expect(parseSms('Cash out the best deals today'), isNull);
    });

    test('ignores a date that does not exist', () {
      final sms = parseSms(
        'Payment Tk 10.00 to Shop successful. TrxID ABCDEF12 at 31/02/2026',
      )!;

      expect(sms.date, isNull);
    });

    test('reads a Bangla message with Bangla digits', () {
      final sms = parseSms(
        'আপনি 500.00 টাকা পেয়েছেন 01712345678 থেকে। ফি 0.00 টাকা। '
        'ব্যালেন্স 1,২00.00 টাকা। TrxID 9GH7K2L2 তারিখ ১০/১০/২০২৬',
      )!;

      expect(sms.kind, SmsKind.received);
      expect(sms.amount, 50000);
      expect(sms.fee, 0);
      expect(sms.balance, 120000);
      expect(sms.trxId, '9GH7K2L2');
      expect(sms.date, DateTime(2026, 10, 10));
    });

    test('reads Cash-Out with a hyphen', () {
      final sms = parseSms(
        'Cash-Out Tk 300.00 to 01712345678. Fee Tk 5.50. Balance Tk 100.00. '
        'TrxID ABC12345',
      )!;

      expect(sms.kind, SmsKind.cashOut);
      expect(sms.amount, 30000);
      expect(sms.fee, 550);
    });

    test('reads deducted as a debit, and the A/C digits', () {
      final sms = parseSms(
        'Your A/C XXXX1234 has been deducted BDT 800.00 at SHWAPNO',
      )!;

      expect(sms.kind, SmsKind.debited);
      expect(sms.amount, 80000);
      expect(sms.accountHint, '1234');
      expect(sms.bankLike, isTrue);
      expect(sms.source, 'ac1234');
    });

    test('reads figures that only carry a label', () {
      final sms = parseSms(
        'Money Received. Amount: 300.00 Fee: 5.00 Balance: 900.00 '
        'TrxID: 7XYZ99AA',
      )!;

      expect(sms.kind, SmsKind.received);
      expect(sms.amount, 30000);
      expect(sms.fee, 500);
      expect(sms.balance, 90000);
    });

    test('an ATM withdrawal is a cash out from a bank', () {
      final sms = parseSms(
        'Tk 5,000.00 withdrawn from ATM using card ending 4321',
      )!;

      expect(sms.kind, SmsKind.cashOut);
      expect(sms.amount, 500000);
      expect(sms.bankLike, isTrue);
      expect(sms.accountHint, '4321');
    });

    test('a credit card purchase is spending, not income', () {
      final sms = parseSms(
        'Your credit card was used for purchase of BDT 2,500.00 at DARAZ',
      )!;

      expect(sms.kind, SmsKind.payment);
      expect(sms.amount, 250000);
    });

    test('tells the kind of sender when the service is not named', () {
      final named = parseSms(
        'bKash: You have received Tk 500.00 from 01712345678. '
        'TrxID 9GH7K2L2',
      )!;
      final unnamed = parseSms(
        'You have received Tk 500.00 from 01712345678. TrxID 9GH7K2L2',
      )!;

      expect(named.source, 'bkash');
      expect(unnamed.provider, isNull);
      expect(unnamed.source, 'id-trxid');
      expect(unnamed.bankLike, isFalse);
    });
  });
}
