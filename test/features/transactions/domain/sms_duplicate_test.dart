import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/transactions/domain/sms_duplicate.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

TransactionItem _item(
  int id, {
  TransactionType type = TransactionType.expense,
  int amount = 50000,
  int accountId = 1,
  bool adjustment = false,
}) => TransactionItem(
  id: id,
  type: type,
  amount: amount,
  accountId: accountId,
  accountName: 'bKash',
  date: DateTime(2026, 10, 10, 12),
  note: '',
  createdAt: DateTime(2026, 10, 10, 12),
  isAdjustment: adjustment,
);

void main() {
  test('finds an entry of the same kind, amount and account', () {
    final found = sameEntryAs(
      [_item(1, amount: 100), _item(2), _item(3, accountId: 2)],
      type: TransactionType.expense,
      amount: 50000,
      accountId: 1,
    );
    expect(found?.id, 2);
  });

  test('another kind, amount or account is not the same', () {
    final items = [_item(1)];
    for (final (type, amount, account) in [
      (TransactionType.income, 50000, 1),
      (TransactionType.expense, 50001, 1),
      (TransactionType.expense, 50000, 2),
    ]) {
      expect(
        sameEntryAs(items, type: type, amount: amount, accountId: account),
        isNull,
      );
    }
  });

  test(
    'a balance fix never counts, and an unknown account matches nothing',
    () {
      expect(
        sameEntryAs(
          [_item(1, adjustment: true)],
          type: TransactionType.expense,
          amount: 50000,
          accountId: 1,
        ),
        isNull,
      );
      expect(
        sameEntryAs(
          [_item(1)],
          type: TransactionType.expense,
          amount: 50000,
          accountId: null,
        ),
        isNull,
      );
    },
  );
}
