import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/accounts/domain/account_activity.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

var _next = 1;

TransactionItem _item(
  TransactionType type,
  int amount, {
  int account = 1,
  int? to,
  bool adjustment = false,
}) => TransactionItem(
  id: _next++,
  type: type,
  amount: amount,
  accountId: account,
  accountName: 'A$account',
  toAccountId: to,
  date: DateTime(2026, 10, 5),
  note: '',
  createdAt: DateTime(2026, 10, 5),
  isAdjustment: adjustment,
);

void main() {
  test('income comes in, spending goes out', () {
    final result = activityByAccount([
      _item(TransactionType.income, 50000),
      _item(TransactionType.expense, 12000),
      _item(TransactionType.expense, 3000),
    ]);

    final cash = result[1]!;
    expect(cash.inflow, 50000);
    expect(cash.outflow, 15000);
    expect(cash.net, 35000);
    expect(cash.count, 3);
  });

  test('a transfer is out of one account and into the other', () {
    final result = activityByAccount([
      _item(TransactionType.transfer, 20000, account: 1, to: 2),
    ]);

    expect(result[1]!.outflow, 20000);
    expect(result[1]!.inflow, 0);
    expect(result[2]!.inflow, 20000);
    expect(result[2]!.outflow, 0);
    expect(result[2]!.count, 1);
  });

  test('a balance fix is not money moving', () {
    final result = activityByAccount([
      _item(TransactionType.income, 9999, adjustment: true),
    ]);
    expect(result, isEmpty);
  });

  test('touching finds what an account sent, received or holds', () {
    final items = [
      _item(TransactionType.expense, 100, account: 1),
      _item(TransactionType.transfer, 200, account: 2, to: 1),
      _item(TransactionType.expense, 300, account: 3),
    ];
    expect(touching(items, 1).map((e) => e.amount), [100, 200]);
    expect(touching(items, 3).map((e) => e.amount), [300]);
    expect(touching(items, 9), isEmpty);
  });
}
