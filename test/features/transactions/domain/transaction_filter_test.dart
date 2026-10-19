import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/transactions/domain/feeling.dart';
import 'package:hishab/features/transactions/domain/transaction_filter.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

TransactionItem item(
  int id, {
  TransactionType type = TransactionType.expense,
  int amount = 10000,
  int accountId = 1,
  int? toAccountId,
  int? categoryId = 10,
  int? parentId,
  String categoryName = 'Food',
  String note = '',
  DateTime? date,
  int? tagId,
  Feeling? feeling,
}) => TransactionItem(
  id: id,
  type: type,
  amount: amount,
  accountId: accountId,
  accountName: 'Cash',
  toAccountId: toAccountId,
  categoryId: type == TransactionType.transfer ? null : categoryId,
  categoryName: type == TransactionType.transfer ? null : categoryName,
  categoryParentId: parentId,
  date: date ?? DateTime(2026, 10, 11, 12),
  note: note,
  tagId: tagId,
  feeling: feeling,
  createdAt: DateTime(2026, 10, 11),
);

List<int> ids(List<TransactionItem> items) => items.map((i) => i.id).toList();

void main() {
  final items = [
    item(1, note: 'Lunch with Rahim', amount: 25000),
    item(
      2,
      type: TransactionType.income,
      categoryId: 20,
      categoryName: 'Salary',
      amount: 5000000,
    ),
    item(
      3,
      type: TransactionType.transfer,
      accountId: 1,
      toAccountId: 2,
      amount: 100000,
    ),
    item(
      4,
      categoryId: 11,
      parentId: 10,
      categoryName: 'Groceries',
      accountId: 2,
      amount: 15050,
    ),
    item(
      5,
      categoryId: 30,
      categoryName: 'Rent',
      note: 'october',
      date: DateTime(2026, 10, 2),
    ),
  ];

  test('no filter keeps everything in order', () {
    expect(ids(applyTransactionFilter(items, const TransactionFilter())), [
      1,
      2,
      3,
      4,
      5,
    ]);
    expect(const TransactionFilter().isActive, isFalse);
  });

  group('type', () {
    test('keeps only that type', () {
      expect(
        ids(
          applyTransactionFilter(
            items,
            const TransactionFilter(type: TransactionType.income),
          ),
        ),
        [2],
      );
      expect(
        ids(
          applyTransactionFilter(
            items,
            const TransactionFilter(type: TransactionType.transfer),
          ),
        ),
        [3],
      );
      expect(
        ids(
          applyTransactionFilter(
            items,
            const TransactionFilter(type: TransactionType.expense),
          ),
        ),
        [1, 4, 5],
      );
    });
  });

  group('category', () {
    test('matches the category itself', () {
      expect(
        ids(
          applyTransactionFilter(
            items,
            const TransactionFilter(categoryId: 30),
          ),
        ),
        [5],
      );
    });

    test('a parent also matches its sub-categories', () {
      expect(
        ids(
          applyTransactionFilter(
            items,
            const TransactionFilter(categoryId: 10),
          ),
        ),
        [1, 4],
      );
    });

    test('a sub-category does not match its parent', () {
      expect(
        ids(
          applyTransactionFilter(
            items,
            const TransactionFilter(categoryId: 11),
          ),
        ),
        [4],
      );
    });
  });

  group('category scope (deep categories)', () {
    // Food (10) > Groceries (11) > Rice (12); Rent (30) is elsewhere.
    final deep = [
      item(1, categoryId: 10),
      item(2, categoryId: 11, parentId: 10, categoryName: 'Groceries'),
      item(3, categoryId: 12, parentId: 11, categoryName: 'Rice'),
      item(4, categoryId: 30, categoryName: 'Rent'),
    ];

    test('the scope reaches categories at any depth', () {
      const filter = TransactionFilter(
        categoryId: 10,
        categoryScope: {10, 11, 12},
      );

      expect(ids(applyTransactionFilter(deep, filter)), [1, 2, 3]);
    });

    test('a category in the middle matches what is inside it only', () {
      const filter = TransactionFilter(categoryId: 11, categoryScope: {11, 12});

      expect(ids(applyTransactionFilter(deep, filter)), [2, 3]);
    });

    test('without a scope the category and its direct children match', () {
      const filter = TransactionFilter(categoryId: 10);

      expect(ids(applyTransactionFilter(deep, filter)), [1, 2]);
    });

    test('the scope is kept when the search text or range changes', () {
      const filter = TransactionFilter(
        categoryId: 10,
        categoryScope: {10, 11, 12},
      );

      expect(filter.withQuery('x').categoryScope, {10, 11, 12});
      expect(filter.withoutRange().categoryScope, {10, 11, 12});
      expect(filter.withoutSheetOptions().categoryScope, isEmpty);
    });
  });

  group('account', () {
    test('matches the account money leaves or arrives in', () {
      expect(
        ids(
          applyTransactionFilter(items, const TransactionFilter(accountId: 2)),
        ),
        [3, 4],
      );
      expect(
        ids(
          applyTransactionFilter(items, const TransactionFilter(accountId: 1)),
        ),
        [1, 2, 3, 5],
      );
    });
  });

  group('date range', () {
    test('includes the start and excludes the end', () {
      final range = (start: DateTime(2026, 10, 2), end: DateTime(2026, 10, 3));
      expect(
        ids(applyTransactionFilter(items, TransactionFilter(range: range))),
        [5],
      );
    });
  });

  group('search text', () {
    List<int> search(String text) =>
        ids(applyTransactionFilter(items, TransactionFilter(query: text)));

    test('matches the note, ignoring case', () {
      expect(search('lunch'), [1]);
      expect(search('  RAHIM '), [1]);
      expect(search('OCT'), [5]);
    });

    test('matches the category name', () {
      expect(search('grocer'), [4]);
      expect(search('salary'), [2]);
    });

    test('matches part of the amount', () {
      expect(search('250'), [1]);
      expect(search('150.5'), [4]);
      expect(search('1,000'), [3]);
      expect(search('50000'), [2]);
    });

    test('matches nothing for unknown text', () {
      expect(search('zzz'), isEmpty);
    });

    test('blank text matches everything', () {
      expect(search('   '), [1, 2, 3, 4, 5]);
    });
  });

  test('all conditions must match together', () {
    final filter = const TransactionFilter(
      type: TransactionType.expense,
      accountId: 1,
      query: 'lunch',
    );

    expect(ids(applyTransactionFilter(items, filter)), [1]);
    expect(filter.isActive, isTrue);
  });

  group('amount range', () {
    final priced = [
      item(1, amount: 10000),
      item(2, amount: 50000),
      item(3, amount: 150000),
    ];

    test('a smallest amount keeps that much and more', () {
      const filter = TransactionFilter(minAmount: 50000);
      expect(ids(applyTransactionFilter(priced, filter)), [2, 3]);
    });

    test('a largest amount keeps that much and less', () {
      const filter = TransactionFilter(maxAmount: 50000);
      expect(ids(applyTransactionFilter(priced, filter)), [1, 2]);
    });

    test('both ends are included', () {
      const filter = TransactionFilter(minAmount: 10000, maxAmount: 50000);
      expect(ids(applyTransactionFilter(priced, filter)), [1, 2]);
    });

    test('an empty range matches nothing', () {
      const filter = TransactionFilter(minAmount: 60000, maxAmount: 90000);
      expect(applyTransactionFilter(priced, filter), isEmpty);
    });
  });

  group('trip or event', () {
    test('keeps only what belongs to the tag', () {
      final tagged = [item(1, tagId: 7), item(2, tagId: 8), item(3)];
      const filter = TransactionFilter(tagId: 7);
      expect(ids(applyTransactionFilter(tagged, filter)), [1]);
    });
  });

  group('feeling', () {
    test('keeps only spending that felt that way', () {
      final felt = [
        item(1, feeling: Feeling.regret),
        item(2, feeling: Feeling.need),
        item(3),
      ];
      const filter = TransactionFilter(feeling: Feeling.regret);
      expect(ids(applyTransactionFilter(felt, filter)), [1]);
    });

    test('works together with the amount', () {
      final felt = [
        item(1, feeling: Feeling.regret, amount: 90000),
        item(2, feeling: Feeling.regret, amount: 10000),
        item(3, feeling: Feeling.need, amount: 90000),
      ];
      const filter = TransactionFilter(
        feeling: Feeling.regret,
        minAmount: 50000,
      );
      expect(ids(applyTransactionFilter(felt, filter)), [1]);
    });
  });

  group('isActive and counting options', () {
    test('the new options make the filter active and are counted', () {
      expect(const TransactionFilter(minAmount: 1).isActive, isTrue);
      expect(const TransactionFilter(maxAmount: 1).isActive, isTrue);
      expect(const TransactionFilter(tagId: 1).isActive, isTrue);
      expect(const TransactionFilter(feeling: Feeling.want).isActive, isTrue);

      // The amount range is one option, whichever ends are set.
      expect(
        const TransactionFilter(
          minAmount: 1,
          maxAmount: 9,
          tagId: 1,
          feeling: Feeling.need,
        ).sheetOptionCount,
        3,
      );
    });

    test('withQuery and withoutRange keep the new options', () {
      final filter = TransactionFilter(
        minAmount: 100,
        maxAmount: 900,
        tagId: 4,
        feeling: Feeling.regret,
        range: (start: DateTime(2026), end: DateTime(2027)),
      );

      for (final kept in [filter.withQuery('x'), filter.withoutRange()]) {
        expect(kept.minAmount, 100);
        expect(kept.maxAmount, 900);
        expect(kept.tagId, 4);
        expect(kept.feeling, Feeling.regret);
      }
      expect(filter.withoutSheetOptions().minAmount, isNull);
      expect(filter.withoutSheetOptions().tagId, isNull);
      expect(filter.withoutSheetOptions().feeling, isNull);
    });

    test('a search text counts as active but not as a sheet option', () {
      const filter = TransactionFilter(query: 'x');
      expect(filter.isActive, isTrue);
      expect(filter.sheetOptionCount, 0);
    });

    test('counts each option of the filter sheet', () {
      final filter = TransactionFilter(
        type: TransactionType.income,
        categoryId: 1,
        accountId: 2,
        range: (start: DateTime(2026), end: DateTime(2027)),
      );
      expect(filter.sheetOptionCount, 4);
    });

    test(
      'withQuery keeps the options and withoutSheetOptions keeps the query',
      () {
        const filter = TransactionFilter(
          query: 'a',
          type: TransactionType.income,
          accountId: 3,
        );

        expect(filter.withQuery('b').type, TransactionType.income);
        expect(filter.withQuery('b').query, 'b');
        expect(filter.withoutSheetOptions().query, 'a');
        expect(filter.withoutSheetOptions().type, isNull);
        expect(filter.withoutSheetOptions().accountId, isNull);
      },
    );
  });
}
