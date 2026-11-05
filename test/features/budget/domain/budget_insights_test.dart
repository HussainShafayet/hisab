import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/budget/domain/budget_insights.dart';
import 'package:hishab/features/budget/domain/budget_item.dart';
import 'package:hishab/features/budget/domain/budget_placement.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

Category _c(int id, String name, [int? parentId]) => Category(
  id: id,
  name: name,
  type: CategoryType.expense,
  parentId: parentId,
  icon: 'category',
  color: 0xFF9E9E9E,
  isArchived: false,
  sortOrder: 0,
);

TransactionItem _tx(
  int amount, {
  int? category,
  TransactionType type = TransactionType.expense,
  bool adjustment = false,
}) => TransactionItem(
  id: amount + (category ?? 0),
  type: type,
  amount: amount,
  accountId: 1,
  accountName: 'Cash',
  date: DateTime(2026, 10, 5),
  note: '',
  createdAt: DateTime(2026, 10, 5),
  categoryId: category,
  isAdjustment: adjustment,
);

BudgetItem _budget(int id, int limit) =>
    BudgetItem(id: id, categoryId: id, limit: limit, spent: 0);

void main() {
  group('projectedSpend', () {
    final october = DateTime(2026, 10);

    test('carries the pace so far to the end of the month', () {
      // 10 days gone, ৳1,000 spent: ৳3,100 for 31 days.
      expect(
        projectedSpend(
          spent: 100000,
          month: october,
          today: DateTime(2026, 10, 10, 15),
        ),
        310000,
      );
    });

    test('is the real total once the month is over', () {
      expect(
        projectedSpend(
          spent: 123,
          month: october,
          today: DateTime(2026, 11, 2),
        ),
        123,
      );
    });

    test('says nothing in the first days or before the month', () {
      expect(
        projectedSpend(
          spent: 99999,
          month: october,
          today: DateTime(2026, 10, 2),
        ),
        isNull,
      );
      expect(
        projectedSpend(spent: 1, month: october, today: DateTime(2026, 9, 30)),
        isNull,
      );
    });
  });

  group('allocationOf', () {
    final byId = {
      for (final c in [_c(1, 'Food'), _c(2, 'Fish', 1), _c(3, 'Rent')]) c.id: c,
    };

    test('counts a budget inside another only once', () {
      final items = [
        _budget(1, 600000),
        _budget(2, 200000),
        _budget(3, 500000),
      ];
      final placements = budgetPlacements({
        for (final i in items) i.categoryId!: i.limit,
      }, byId);

      final allocation = allocationOf(
        limit: 1500000,
        items: items,
        placements: placements,
      );
      expect(allocation.planned, 1100000);
      expect(allocation.unplanned, 400000);
      expect(allocation.over, isFalse);
    });

    test('says when the categories ask for more than the month', () {
      final items = [_budget(1, 900000), _budget(3, 500000)];
      final placements = budgetPlacements({
        for (final i in items) i.categoryId!: i.limit,
      }, byId);

      final allocation = allocationOf(
        limit: 1000000,
        items: items,
        placements: placements,
      );
      expect(allocation.over, isTrue);
      expect(allocation.unplanned, -400000);
    });
  });

  group('unbudgetedSpending', () {
    final byId = {
      for (final c in [
        _c(1, 'Food'),
        _c(2, 'Fish', 1),
        _c(3, 'Rent'),
        _c(4, 'Fun'),
      ])
        c.id: c,
    };

    test('adds up what no budget covers, by top-level category', () {
      final result = unbudgetedSpending(
        [
          _tx(1000, category: 3),
          _tx(2000, category: 2),
          _tx(500, category: 4),
          _tx(300),
          // Covered by a budget on Fun.
          _tx(9000, category: 5),
          _tx(777, type: TransactionType.income, category: 3),
          _tx(888, category: 3, adjustment: true),
        ],
        covered: {5},
        byId: byId,
        noCategoryName: 'No category',
      );

      expect(result.total, 3800);
      expect(result.top.map((g) => g.name), ['Food', 'Rent', 'Fun']);
      expect(result.top.first.total, 2000);
    });

    test('names spending with no category', () {
      final result = unbudgetedSpending(
        [_tx(300)],
        covered: const {},
        byId: byId,
        noCategoryName: 'No category',
      );
      expect(result.top.single.categoryId, isNull);
      expect(result.top.single.name, 'No category');
    });

    test('nothing uncovered gives zero', () {
      final result = unbudgetedSpending(
        [_tx(100, category: 3)],
        covered: {3},
        byId: byId,
        noCategoryName: 'No category',
      );
      expect(result.total, 0);
      expect(result.top, isEmpty);
    });
  });
}
