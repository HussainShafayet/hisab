import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/reports/domain/report_highlights.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

var _next = 1;

TransactionItem _expense(
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
  isAdjustment: adjustment,
);

void main() {
  final october = monthRange(DateTime(2026, 10));

  test('finds the biggest day, the average and the no-spend days', () {
    final facts = highlightsOf(
      [
        _expense(10000, DateTime(2026, 10, 5, 9)),
        _expense(20000, DateTime(2026, 10, 5, 19)),
        _expense(6000, DateTime(2026, 10, 7)),
        _expense(99999, DateTime(2026, 10, 8), adjustment: true),
        _expense(5000, DateTime(2026, 10, 8), type: TransactionType.transfer),
      ],
      range: october,
      now: DateTime(2026, 10, 10, 12),
    );

    expect(facts.expenseCount, 3);
    expect(facts.averageExpense, 12000);
    expect(facts.biggestDay, DateTime(2026, 10, 5));
    expect(facts.biggestDayTotal, 30000);
    // 10 days so far, 2 of them with spending.
    expect(facts.daysInPeriod, 10);
    expect(facts.noSpendDays, 8);
  });

  test('adds up each weekday, Sunday first', () {
    // 4 Oct 2026 is a Sunday, 5 Oct a Monday.
    final facts = highlightsOf(
      [
        _expense(1000, DateTime(2026, 10, 4)),
        _expense(2000, DateTime(2026, 10, 11)),
        _expense(500, DateTime(2026, 10, 5)),
      ],
      range: october,
      now: DateTime(2026, 10, 20),
    );

    expect(facts.byWeekday, [3000, 500, 0, 0, 0, 0, 0]);
    expect(facts.busiestWeekday, 0);
  });

  test('a finished month counts all its days', () {
    final facts = highlightsOf(
      [_expense(100, DateTime(2026, 10, 1))],
      range: october,
      now: DateTime(2026, 12, 1),
    );
    expect(facts.daysInPeriod, 31);
    expect(facts.noSpendDays, 30);
  });

  test('no spending gives nothing to point at', () {
    final facts = highlightsOf([], range: october, now: DateTime(2026, 10, 10));
    expect(facts.expenseCount, 0);
    expect(facts.biggestDay, isNull);
    expect(facts.busiestWeekday, isNull);
    expect(facts.noSpendDays, 10);
  });
}
