import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_stats.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

var _next = 1;

TransactionItem _item({
  required int amount,
  TransactionType type = TransactionType.expense,
  String? category = 'Food',
  bool adjustment = false,
}) => TransactionItem(
  id: _next++,
  type: type,
  amount: amount,
  accountId: 1,
  accountName: 'Cash',
  date: DateTime(2026, 10, 5),
  note: '',
  createdAt: DateTime(2026, 10, 5),
  categoryName: category,
  isAdjustment: adjustment,
);

void main() {
  final october = monthRange(DateTime(2026, 10));

  test('counts entries, the biggest expense and the top category', () {
    final stats = statsOf(
      [
        _item(amount: 10000),
        _item(amount: 30000, category: 'Rent'),
        _item(amount: 5000),
        _item(amount: 900000, type: TransactionType.income, category: 'Pay'),
        _item(amount: 1000, type: TransactionType.transfer, category: null),
        _item(amount: 99999, adjustment: true),
      ],
      range: october,
      now: DateTime(2026, 10, 10, 12),
    );

    expect(stats.count, 5);
    expect(stats.biggestExpense?.amount, 30000);
    expect(stats.topCategory, (name: 'Rent', total: 30000));
  });

  test('the daily average counts the days so far in a month that is going', () {
    final stats = statsOf(
      [_item(amount: 100000)],
      range: october,
      now: DateTime(2026, 10, 10, 12),
    );
    // 10 days so far.
    expect(stats.expensePerDay, 10000);
  });

  test('a finished month counts all its days', () {
    final stats = statsOf(
      [_item(amount: 310000)],
      range: october,
      now: DateTime(2026, 12, 1),
    );
    expect(stats.expensePerDay, 10000);
  });

  test('nothing gives zeros and no biggest', () {
    final stats = statsOf([], range: october, now: DateTime(2026, 10, 10));
    expect(stats.count, 0);
    expect(stats.expensePerDay, 0);
    expect(stats.biggestExpense, isNull);
    expect(stats.topCategory, isNull);
  });
}
