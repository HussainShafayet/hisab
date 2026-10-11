import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/transactions/domain/day_groups.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

TransactionItem item(int id, TransactionType type, int amount, DateTime date) =>
    TransactionItem(
      id: id,
      type: type,
      amount: amount,
      accountId: 1,
      accountName: 'Cash',
      date: date,
      note: '',
      createdAt: date,
    );

void main() {
  const income = TransactionType.income;
  const expense = TransactionType.expense;
  const transfer = TransactionType.transfer;

  group('totalsOf', () {
    test('is zero for no transactions', () {
      expect(totalsOf([]), (income: 0, expense: 0));
    });

    test('adds income and expense separately', () {
      final totals = totalsOf([
        item(1, income, 5000, DateTime(2026, 10, 1)),
        item(2, expense, 1200, DateTime(2026, 10, 1)),
        item(3, expense, 300, DateTime(2026, 10, 2)),
        item(4, income, 100, DateTime(2026, 10, 2)),
      ]);

      expect(totals, (income: 5100, expense: 1500));
    });

    test('does not count transfers', () {
      final totals = totalsOf([
        item(1, transfer, 99999, DateTime(2026, 10, 1)),
        item(2, expense, 100, DateTime(2026, 10, 1)),
      ]);

      expect(totals, (income: 0, expense: 100));
    });
  });

  group('groupByDay', () {
    test('is empty for no transactions', () {
      expect(groupByDay([]), isEmpty);
    });

    test('groups by calendar day, newest day first', () {
      final groups = groupByDay([
        item(1, expense, 100, DateTime(2026, 10, 11, 20)),
        item(2, expense, 200, DateTime(2026, 10, 11, 9)),
        item(3, income, 300, DateTime(2026, 10, 9, 12)),
      ]);

      expect(groups.map((g) => g.day), [
        DateTime(2026, 10, 11),
        DateTime(2026, 10, 9),
      ]);
      expect(groups[0].items.map((i) => i.id), [1, 2]);
      expect(groups[1].items.map((i) => i.id), [3]);
    });

    test('sorts days even when the input is not sorted', () {
      final groups = groupByDay([
        item(1, expense, 100, DateTime(2026, 10, 1)),
        item(2, expense, 100, DateTime(2026, 10, 3)),
        item(3, expense, 100, DateTime(2026, 10, 2)),
      ]);

      expect(groups.map((g) => g.day.day), [3, 2, 1]);
    });

    test('splits at local midnight', () {
      final groups = groupByDay([
        item(1, expense, 100, DateTime(2026, 10, 11, 0, 0, 1)),
        item(2, expense, 100, DateTime(2026, 10, 10, 23, 59, 59)),
      ]);

      expect(groups, hasLength(2));
    });

    test('a UTC time is grouped by its local day', () {
      final utc = DateTime.utc(2026, 10, 11, 12);
      final groups = groupByDay([item(1, expense, 100, utc)]);

      expect(
        groups.single.day,
        DateTime(utc.toLocal().year, utc.toLocal().month, utc.toLocal().day),
      );
    });

    test('each group has its own income and expense totals', () {
      final groups = groupByDay([
        item(1, expense, 100, DateTime(2026, 10, 11)),
        item(2, income, 900, DateTime(2026, 10, 11)),
        item(3, transfer, 5000, DateTime(2026, 10, 11)),
        item(4, expense, 40, DateTime(2026, 10, 10)),
      ]);

      expect(groups[0].income, 900);
      expect(groups[0].expense, 100);
      expect(groups[1].income, 0);
      expect(groups[1].expense, 40);
    });
  });
}
