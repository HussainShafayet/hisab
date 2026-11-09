import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/database/category_fixes.dart';
import 'package:hishab/features/categories/data/categories_repository.dart';
import 'package:hishab/features/categories/data/category_tidy.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late Basics b;

  setUp(() async {
    db = createTestDatabase();
    b = await seedBasics(db);
  });
  tearDown(() => db.close());

  Future<int> spend(int category, int amount) => addTransaction(
    db,
    type: TransactionType.expense,
    amount: amount,
    accountId: b.cash,
    categoryId: category,
    date: DateTime(2026, 10, 5, 12),
  );

  Future<CategoryRow> row(int id) async =>
      (await db.categoriesDao.getAll(includeArchived: true))
          .firstWhere((c) => c.id == id);

  Future<List<CategoryRow>> active() async =>
      (await db.categoriesDao.getAll()).toList();

  group('family by person', () {
    /// The layout of an install from before: Pocket money > Wife / Children
    /// and a Children group of its own with a Pocket money inside.
    Future<
      ({
        int family,
        int pocket,
        int wife,
        int husband,
        int kidsLeaf,
        int children,
        int childPocket,
      })
    >
    oldFamily() async {
      final family = await insertTestCategory(db, name: 'Family & gifts');
      final pocket = await insertTestCategory(
        db,
        name: 'Pocket money',
        parentId: family,
      );
      final wife = await insertTestCategory(db, name: 'Wife', parentId: pocket);
      final husband = await insertTestCategory(
        db,
        name: 'Husband',
        parentId: pocket,
      );
      final kidsLeaf = await insertTestCategory(
        db,
        name: 'Children',
        parentId: pocket,
      );
      final children = await insertTestCategory(
        db,
        name: 'Children',
        parentId: family,
      );
      final childPocket = await insertTestCategory(
        db,
        name: 'Pocket money',
        parentId: children,
      );
      return (
        family: family,
        pocket: pocket,
        wife: wife,
        husband: husband,
        kidsLeaf: kidsLeaf,
        children: children,
        childPocket: childPocket,
      );
    }

    test(
      'moves Pocket money > Wife into a Wife group, keeping its id',
      () async {
        final f = await oldFamily();
        final tx = await spend(f.wife, 5000);

        final result = await CategoryTidy(db).familyByPerson();

        expect(result.moved, greaterThanOrEqualTo(2));
        final moved = await row(f.wife);
        expect(moved.name, 'Pocket money');
        final group = await row(moved.parentId!);
        expect(group.name, 'Wife');
        expect(group.parentId, f.family);
        expect((await db.transactionsDao.getById(tx))!.categoryId, f.wife);
      },
    );

    test(
      'merges the old Pocket money > Children into Children > Pocket money',
      () async {
        final f = await oldFamily();
        final a = await spend(f.kidsLeaf, 1000);
        final c = await spend(f.childPocket, 2000);

        final result = await CategoryTidy(db).familyByPerson();

        expect(result.merged, 1);
        expect(result.transactions, 1);
        expect((await row(f.kidsLeaf)).isArchived, isTrue);
        expect(
          (await db.transactionsDao.getById(a))!.categoryId,
          f.childPocket,
        );
        expect(
          (await db.transactionsDao.getById(c))!.categoryId,
          f.childPocket,
        );
      },
    );

    test('puts the empty Pocket money group away', () async {
      final f = await oldFamily();

      await CategoryTidy(db).familyByPerson();

      expect((await row(f.pocket)).isArchived, isTrue);
    });

    test('does nothing on an install without that layout', () async {
      final result = await CategoryTidy(db).familyByPerson();
      expect(result.isEmpty, isTrue);
    });

    test('the second run finds nothing more to do', () async {
      await oldFamily();
      await CategoryTidy(db).run();

      final again = await CategoryTidy(db).run();

      expect(again.isEmpty, isTrue);
    });
  });

  group('doubles', () {
    test('folds the same name in the same place into the busier one', () async {
      final keep = await insertTestCategory(db, name: 'Gifts');
      final dupe = await insertTestCategory(db, name: 'gifts ');
      final one = await spend(keep, 100);
      final two = await spend(dupe, 200);
      final three = await spend(dupe, 300);

      final result = await CategoryTidy(db).mergeDoubles();

      expect(result.merged, 1);
      expect((await row(keep)).isArchived, isTrue);
      expect((await row(dupe)).isArchived, isFalse);
      for (final id in [one, two, three]) {
        expect((await db.transactionsDao.getById(id))!.categoryId, dupe);
      }
    });

    test(
      'moves what is inside the double and merges the doubles in there',
      () async {
        final keep = await insertTestCategory(db, name: 'Gifts');
        final dupe = await insertTestCategory(db, name: 'Gifts');
        final inKeep = await insertTestCategory(
          db,
          name: 'Eid',
          parentId: keep,
        );
        final inDupe = await insertTestCategory(
          db,
          name: 'Eid',
          parentId: dupe,
        );
        final only = await insertTestCategory(
          db,
          name: 'Wedding',
          parentId: dupe,
        );
        final tx = await spend(inDupe, 500);
        await spend(keep, 100);
        await spend(keep, 100);

        await CategoryTidy(db).mergeDoubles();

        final names = {for (final c in await active()) c.id: c};
        expect(names.containsKey(dupe), isFalse);
        expect(names[only]!.parentId, keep);
        // The two Eid became one, and the entry went with it.
        final eids = names.values.where((c) => c.name == 'Eid').toList();
        expect(eids, hasLength(1));
        expect(
          (await db.transactionsDao.getById(tx))!.categoryId,
          eids.single.id,
        );
        expect([inKeep, inDupe], contains(eids.single.id));
      },
    );

    test('leaves the same name in two places alone', () async {
      final wife = await insertTestCategory(db, name: 'Wife');
      final kids = await insertTestCategory(db, name: 'Children');
      await insertTestCategory(db, name: 'Clothes', parentId: wife);
      await insertTestCategory(db, name: 'Clothes', parentId: kids);

      final result = await CategoryTidy(db).mergeDoubles();

      expect(result.isEmpty, isTrue);
    });

    test('keeps expense and income apart', () async {
      await insertTestCategory(db, name: 'Gift');
      await insertTestCategory(db, name: 'Gift', type: CategoryType.income);

      expect((await CategoryTidy(db).mergeDoubles()).isEmpty, isTrue);
    });
  });

  group('tidyCategories (schema 20)', () {
    test('does not stop the app when there is nothing to tidy', () async {
      await expectLater(tidyCategories(db), completes);
    });

    test(
      'adds the people of the house to an install made with the defaults',
      () async {
        final food = await insertTestCategory(db, name: 'Food');
        await insertTestCategory(db, name: 'Kacha bazar', parentId: food);

        await tidyCategories(db);

        final names = [for (final c in await active()) c.name];
        expect(names, containsAll(['Wife', 'Husband', 'Children']));
      },
    );
  });

  group('feeCategoryId', () {
    test('finds the category that exists', () async {
      final late = await insertTestCategory(db, name: 'Late fee');
      expect(await CategoriesRepository(db).feeCategoryId('late fee'), late);
    });

    test('makes it inside Fees & charges when it is missing', () async {
      final group = await insertTestCategory(db, name: 'Fees & charges');

      final id = await CategoriesRepository(db).feeCategoryId('Card interest');

      final made = await row(id);
      expect(made.name, 'Card interest');
      expect(made.parentId, group);
      expect(made.type, CategoryType.expense);
    });

    test('makes it on top when there is no such group', () async {
      final id = await CategoriesRepository(db).feeCategoryId('Over-limit fee');
      expect((await row(id)).parentId, isNull);
    });
  });
}
