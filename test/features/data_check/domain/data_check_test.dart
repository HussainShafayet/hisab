import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/data_check/domain/data_check.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

// Today is Sunday 11 October 2026.
final now = DateTime(2026, 10, 11, 14, 30);

var _next = 1;

TransactionItem entry({
  int amount = 120000,
  TransactionType type = TransactionType.expense,
  DateTime? date,
  String note = '',
  int accountId = 1,
  int? toAccountId,
  int? categoryId = 10,
  String? categoryName = 'Food',
  bool adjustment = false,
}) {
  final id = _next++;
  return TransactionItem(
    id: id,
    type: type,
    amount: amount,
    accountId: accountId,
    accountName: 'Cash',
    toAccountId: toAccountId,
    date: date ?? DateTime(2026, 10, 5, 12),
    note: note,
    createdAt: DateTime(2026, 10, 5, 12).add(Duration(minutes: id)),
    categoryId: categoryId,
    categoryName: categoryName,
    isAdjustment: adjustment,
  );
}

Category category(
  int id,
  String name, {
  int? parentId,
  CategoryType type = CategoryType.expense,
  bool archived = false,
}) => Category(
  id: id,
  name: name,
  type: type,
  parentId: parentId,
  icon: 'category',
  color: 0xFF000000,
  isArchived: archived,
  sortOrder: 0,
);

DataCheck check(
  List<TransactionItem> transactions, {
  List<Category> categories = const [],
}) => checkData(transactions: transactions, categories: categories, now: now);

void main() {
  group('entries made twice', () {
    test('the same day, kind, amount, account and note are a group', () {
      final a = entry(note: 'Rent');
      final b = entry(note: 'rent ');

      final result = check([a, b, entry(note: 'Other thing')]);

      expect(result.duplicates, hasLength(1));
      expect(result.duplicates.single.items.map((t) => t.id), [a.id, b.id]);
      expect(result.duplicates.single.extra, 1);
    });

    test('three copies are one group with two extra', () {
      final result = check([entry(), entry(), entry()]);

      expect(result.duplicates.single.items, hasLength(3));
      expect(result.duplicates.single.extra, 2);
    });

    test('another day, amount, account, kind or note is not a copy', () {
      final result = check([
        entry(),
        entry(date: DateTime(2026, 10, 6, 12)),
        entry(amount: 130000),
        entry(accountId: 2),
        entry(type: TransactionType.income),
        entry(note: 'something'),
      ]);

      expect(result.duplicates, isEmpty);
    });

    test('the time of the day does not matter', () {
      final result = check([
        entry(date: DateTime(2026, 10, 5, 8)),
        entry(date: DateTime(2026, 10, 5, 22)),
      ]);

      expect(result.duplicates, hasLength(1));
    });

    test('small amounts are left alone: two rickshaws are a day', () {
      final result = check([entry(amount: 2000), entry(amount: 2000)]);

      expect(result.duplicates, isEmpty);
      // From ৳500 they count.
      expect(
        check([
          entry(amount: duplicateMinAmount),
          entry(amount: duplicateMinAmount),
        ]).duplicates,
        hasLength(1),
      );
    });

    test('a balance correction is not an entry of the person', () {
      final result = check([entry(adjustment: true), entry(adjustment: true)]);

      expect(result.duplicates, isEmpty);
    });

    test('the newest group comes first', () {
      final result = check([
        entry(date: DateTime(2026, 9, 1, 12)),
        entry(date: DateTime(2026, 9, 1, 12)),
        entry(amount: 99000, date: DateTime(2026, 10, 2, 12)),
        entry(amount: 99000, date: DateTime(2026, 10, 2, 12)),
      ]);

      expect(result.duplicates.first.items.first.amount, 99000);
    });
  });

  group('dates in the future', () {
    test('after today, the soonest first', () {
      final late = entry(date: DateTime(2026, 12, 1, 12));
      final soon = entry(date: DateTime(2026, 10, 12, 9));

      final result = check([late, soon, entry()]);

      expect(result.futureDated.map((t) => t.id), [soon.id, late.id]);
    });

    test('today, at any hour, is not the future', () {
      final result = check([
        entry(date: DateTime(2026, 10, 11, 23, 59)),
        entry(date: DateTime(2026, 10, 11, 0, 1)),
      ]);

      expect(result.futureDated, isEmpty);
    });
  });

  group('far above the usual', () {
    List<TransactionItem> food(List<int> amounts) => [
      for (final amount in amounts)
        entry(
          amount: amount,
          date: DateTime(2026, 9, 1 + amounts.indexOf(amount)),
        ),
    ];

    test('ten times the usual, and ৳1,000 or more, is listed', () {
      // Usual is ৳100; ৳4,000 is forty times that.
      final big = entry(amount: 400000, categoryId: 10);
      final result = check([
        for (var i = 0; i < 8; i++)
          entry(amount: 10000, date: DateTime(2026, 9, 1 + i), categoryId: 10),
        big,
      ]);

      expect(result.unusuallyLarge.map((t) => t.id), [big.id]);
    });

    test('a category with few entries has no usual', () {
      final result = check([
        for (var i = 0; i < largeMinEntries - 2; i++)
          entry(amount: 10000, date: DateTime(2026, 9, 1 + i)),
        entry(amount: 400000),
      ]);

      expect(result.unusuallyLarge, isEmpty);
    });

    test(
      'a small amount is not large however large it is against the rest',
      () {
        // Usual ৳1; ৳30 is thirty times that but under ৳1,000.
        final result = check([
          for (var i = 0; i < 9; i++)
            entry(amount: 100, date: DateTime(2026, 9, 1 + i)),
          entry(amount: 3000),
        ]);

        expect(result.unusuallyLarge, isEmpty);
      },
    );

    test('income and transfers are not looked at', () {
      final result = check([
        for (var i = 0; i < 9; i++)
          entry(
            amount: 10000,
            type: TransactionType.income,
            date: DateTime(2026, 9, 1 + i),
          ),
        entry(amount: 900000, type: TransactionType.income),
      ]);

      expect(result.unusuallyLarge, isEmpty);
    });

    test('is looked at for each category by itself', () {
      final fares = [
        for (var i = 0; i < 8; i++)
          entry(
            amount: 500000,
            categoryId: 20,
            categoryName: 'Rent',
            date: DateTime(2026, 9, 1 + i),
          ),
      ];
      final result = check([
        ...fares,
        for (var i = 0; i < 8; i++)
          entry(amount: 10000, date: DateTime(2026, 9, 1 + i)),
      ]);

      // ৳5,000 is the usual of Rent, however big it is next to Food.
      expect(result.unusuallyLarge, isEmpty);
      expect(food([1]).length, 1);
    });

    test('biggest first, and not more than are listed', () {
      final result = check([
        for (var i = 0; i < 30; i++)
          entry(amount: 10000, date: DateTime(2026, 8, 1 + i % 28)),
        for (var i = 0; i < 25; i++)
          entry(amount: 200000 + i * 1000, date: DateTime(2026, 9, 1 + i)),
      ]);

      expect(result.unusuallyLarge, hasLength(maxListed));
      expect(
        result.unusuallyLarge.first.amount,
        greaterThan(result.unusuallyLarge.last.amount),
      );
    });
  });

  group('in Other', () {
    test('counts what is in Other and Other income, with its total', () {
      final result = check([
        entry(amount: 3000, categoryName: 'Other'),
        entry(amount: 5000, categoryName: 'other'),
        entry(
          amount: 7000,
          type: TransactionType.income,
          categoryName: 'Other income',
        ),
        entry(amount: 9000),
      ]);

      expect(result.other!.count, 3);
      expect(result.other!.total, 15000);
      expect(result.other!.items.first.amount, 7000);
    });

    test('nothing in Other is nothing to say', () {
      expect(check([entry()]).other, isNull);
    });

    test('a transfer has no category', () {
      final result = check([
        entry(
          type: TransactionType.transfer,
          toAccountId: 2,
          categoryId: null,
          categoryName: null,
        ),
      ]);

      expect(result.other, isNull);
    });
  });

  group('categories that look alike', () {
    test('Utility and Utilities are a pair, once', () {
      final result = check(
        const [],
        categories: [
          category(1, 'Utilities'),
          category(2, 'Utility bills'),
          category(3, 'Rickshaw'),
        ],
      );

      expect(result.similarCategories, hasLength(1));
      expect(
        {
          result.similarCategories.single.first.id,
          result.similarCategories.single.second.id,
        },
        {1, 2},
      );
    });

    test('the same name under two groups is on purpose', () {
      final result = check(
        const [],
        categories: [
          category(1, 'Family'),
          category(2, 'Gifts', parentId: 1),
          category(3, 'Wife'),
          category(4, 'Gifts', parentId: 3),
        ],
      );

      expect(result.similarCategories, isEmpty);
    });

    test('a group and what is inside it belong together', () {
      final result = check(
        const [],
        categories: [
          category(1, 'Health'),
          category(2, 'Health check', parentId: 1),
        ],
      );

      expect(result.similarCategories, isEmpty);
    });

    test('income and expense are not compared, nor archived ones', () {
      final result = check(
        const [],
        categories: [
          category(1, 'Rent'),
          category(2, 'Rent income', type: CategoryType.income),
          category(3, 'Rent and bills', archived: true),
        ],
      );

      expect(result.similarCategories, isEmpty);
    });
  });

  group('the whole check', () {
    test('nothing to look at is clean', () {
      final result = check([entry()]);

      expect(result.isClean, isTrue);
      expect(result.findings, 0);
    });

    test('counts what there is to look at', () {
      final result = check([
        entry(),
        entry(),
        entry(date: DateTime(2027, 1, 1)),
        entry(categoryName: 'Other', amount: 1000),
      ]);

      // A pair of copies, a date in the future, and Other.
      expect(result.findings, 3);
      expect(result.isClean, isFalse);
    });

    test('an empty app is clean', () {
      expect(check(const []).isClean, isTrue);
    });
  });
}
