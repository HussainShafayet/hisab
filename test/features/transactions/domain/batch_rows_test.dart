import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/transactions/domain/batch_rows.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

final _date = DateTime(2026, 10, 11, 14, 30);

BatchDraft draft({
  TransactionType type = TransactionType.expense,
  String amount = '100',
  int? account = 1,
  int? to,
  int? category = 5,
  String note = '',
}) => BatchDraft(
  type: type,
  amountText: amount,
  accountId: account,
  toAccountId: to,
  categoryId: category,
  note: note,
);

void main() {
  group('isBlank', () {
    test('is true with no amount, category or note', () {
      expect(draft(amount: '', category: null).isBlank, isTrue);
      expect(draft(amount: '  ', category: null, note: ' ').isBlank, isTrue);
    });

    test('ignores the accounts, which every new row starts with', () {
      expect(draft(amount: '', category: null, to: 2).isBlank, isTrue);
    });

    test('is false once anything else is filled in', () {
      expect(draft(amount: '5', category: null).isBlank, isFalse);
      expect(draft(amount: '', category: 5).isBlank, isFalse);
      expect(draft(amount: '', category: null, note: 'x').isBlank, isFalse);
    });
  });

  group('parseBatchDraft', () {
    test('turns an expense into a transaction', () {
      final parsed = parseBatchDraft(draft(note: 'rice'), _date);
      expect(parsed.error, isNull);
      final input = parsed.input!;
      expect(input.type, TransactionType.expense);
      expect(input.amount, 10000);
      expect(input.accountId, 1);
      expect(input.categoryId, 5);
      expect(input.toAccountId, isNull);
      expect(input.date, _date);
      expect(input.note, 'rice');
    });

    test('turns a transfer into a transaction with no category', () {
      final parsed = parseBatchDraft(
        draft(type: TransactionType.transfer, to: 2),
        _date,
      );
      final input = parsed.input!;
      expect(input.toAccountId, 2);
      expect(input.categoryId, isNull);
    });

    test('drops a second account that an income or expense carried', () {
      final parsed = parseBatchDraft(draft(to: 2), _date);
      expect(parsed.input!.toAccountId, isNull);
    });

    test('asks for an amount', () {
      for (final amount in ['', '0', 'abc']) {
        final parsed = parseBatchDraft(draft(amount: amount), _date);
        expect(parsed.input, isNull, reason: amount);
        expect(parsed.error, 'Enter an amount.', reason: amount);
      }
    });

    test('asks for an account', () {
      final parsed = parseBatchDraft(draft(account: null), _date);
      expect(parsed.error, 'Choose an account.');
    });

    test('asks for a category, except on a transfer', () {
      expect(
        parseBatchDraft(draft(category: null), _date).error,
        'Choose a category.',
      );
      expect(
        parseBatchDraft(
          draft(type: TransactionType.transfer, category: null, to: 2),
          _date,
        ).error,
        isNull,
      );
    });

    test(
      'asks for the second account of a transfer, and two different ones',
      () {
        final transfer = TransactionType.transfer;
        expect(
          parseBatchDraft(draft(type: transfer), _date).error,
          'Choose the account the money goes to.',
        );
        expect(
          parseBatchDraft(draft(type: transfer, to: 1), _date).error,
          'Choose two different accounts.',
        );
      },
    );
  });
}
