import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/insights/domain/habits.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

var _next = 1;

TransactionItem _spend(
  int category,
  String name,
  int amount,
  DateTime date, {
  bool adjustment = false,
  TransactionType type = TransactionType.expense,
}) => TransactionItem(
  id: _next++,
  type: type,
  amount: amount,
  accountId: 1,
  accountName: 'Cash',
  date: date,
  note: '',
  createdAt: date,
  categoryId: category,
  categoryName: name,
  isAdjustment: adjustment,
);

void main() {
  final today = DateTime(2026, 10, 25, 20);

  List<TransactionItem> times(
    int category,
    String name,
    int n, {
    int amount = 3000,
    int fromDay = 24,
  }) => [
    for (var i = 0; i < n; i++)
      _spend(category, name, amount, DateTime(2026, 10, fromDay - (i % 20), 9)),
  ];

  test('a category spent on eight times in 30 days is a habit', () {
    final habits = habitsOf(times(1, 'Cha', 8), today: today);

    expect(habits, hasLength(1));
    expect(habits.single.name, 'Cha');
    expect(habits.single.count, 8);
    expect(habits.single.total, 24000);
    // 30 days in the window: a month of it.
    expect(habits.single.perMonth, 24000);
  });

  test('seven times is not yet a habit', () {
    expect(habitsOf(times(1, 'Cha', 7), today: today), isEmpty);
  });

  test('the habit that costs most comes first, and few are kept', () {
    final habits = habitsOf([
      ...times(1, 'Cha', 9, amount: 2000),
      ...times(2, 'Rickshaw', 9, amount: 6000),
      ...times(3, 'Snacks', 9, amount: 4000),
      ...times(4, 'Fuchka', 9, amount: 1000),
    ], today: today);
    expect(habits.map((h) => h.name), ['Rickshaw', 'Snacks', 'Cha']);
  });

  test('old entries, transfers and corrections do not count', () {
    final habits = habitsOf([
      for (var i = 0; i < 10; i++)
        _spend(1, 'Cha', 3000, DateTime(2026, 8, 1 + i)),
      for (var i = 0; i < 10; i++)
        _spend(2, 'Fix', 3000, DateTime(2026, 10, 20), adjustment: true),
      for (var i = 0; i < 10; i++)
        _spend(
          3,
          'Move',
          3000,
          DateTime(2026, 10, 20),
          type: TransactionType.transfer,
        ),
    ], today: today);
    expect(habits, isEmpty);
  });
}
