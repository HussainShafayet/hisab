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

  group('one place for each thing', () {
    /// The general places, and a person's group that repeats them.
    Future<
      ({
        int clothing,
        int jewellery,
        int medicine,
        int doctorVisit,
        int gifts,
        int outings,
        int wife,
        int kids,
        int wifeClothes,
        int wifeMedicine,
        int kidsMedicine,
        int wifeDoctor,
        int wifeGifts,
        int kidsOutings,
        int wifePocket,
        int kidsPocket,
      })
    >
    layout() async {
      final shopping = await insertTestCategory(db, name: 'Shopping');
      final clothing = await insertTestCategory(
        db,
        name: 'Clothing',
        parentId: shopping,
      );
      final jewellery = await insertTestCategory(
        db,
        name: 'Jewellery',
        parentId: clothing,
      );
      final health = await insertTestCategory(db, name: 'Health');
      final medicine = await insertTestCategory(
        db,
        name: 'Medicine',
        parentId: health,
      );
      final tests = await insertTestCategory(
        db,
        name: 'Doctor & tests',
        parentId: health,
      );
      final doctorVisit = await insertTestCategory(
        db,
        name: 'Doctor visit',
        parentId: tests,
      );
      final entertainment = await insertTestCategory(db, name: 'Entertainment');
      final outings = await insertTestCategory(
        db,
        name: 'Outings',
        parentId: entertainment,
      );
      final family = await insertTestCategory(db, name: 'Family & gifts');
      final gifts = await insertTestCategory(
        db,
        name: 'Gifts',
        parentId: family,
      );
      final wife = await insertTestCategory(db, name: 'Wife', parentId: family);
      final kids = await insertTestCategory(
        db,
        name: 'Children',
        parentId: family,
      );
      Future<int> inside(int parent, String name) =>
          insertTestCategory(db, name: name, parentId: parent);
      return (
        clothing: clothing,
        jewellery: jewellery,
        medicine: medicine,
        doctorVisit: doctorVisit,
        gifts: gifts,
        outings: outings,
        wife: wife,
        kids: kids,
        wifeClothes: await inside(wife, 'Clothes'),
        wifeMedicine: await inside(wife, 'Medicine'),
        kidsMedicine: await inside(kids, 'Medicine'),
        wifeDoctor: await inside(wife, 'Doctor'),
        wifeGifts: await inside(wife, 'Gifts'),
        kidsOutings: await inside(kids, 'Outings'),
        wifePocket: await inside(wife, 'Pocket money'),
        kidsPocket: await inside(kids, 'Pocket money'),
      );
    }

    test(
      'folds what every person has into the one place, with its entries',
      () async {
        final t = await layout();
        final clothes = await spend(t.wifeClothes, 500);
        final medicine = await spend(t.wifeMedicine, 300);
        final kidsMedicine = await spend(t.kidsMedicine, 200);
        final doctor = await spend(t.wifeDoctor, 700);
        final gift = await spend(t.wifeGifts, 900);
        final outing = await spend(t.kidsOutings, 400);

        final result = await CategoryTidy(db).personRepeats();

        expect(result.merged, 6);
        expect(result.transactions, 6);
        Future<int?> categoryOf(int id) async =>
            (await db.transactionsDao.getById(id))!.categoryId;
        expect(await categoryOf(clothes), t.clothing);
        expect(await categoryOf(medicine), t.medicine);
        expect(await categoryOf(kidsMedicine), t.medicine);
        expect(await categoryOf(doctor), t.doctorVisit);
        expect(await categoryOf(gift), t.gifts);
        expect(await categoryOf(outing), t.outings);
        // The repeats are put away.
        for (final id in [
          t.wifeClothes,
          t.wifeMedicine,
          t.kidsMedicine,
          t.wifeDoctor,
          t.wifeGifts,
          t.kidsOutings,
        ]) {
          expect((await row(id)).isArchived, isTrue);
        }
      },
    );

    test('leaves Pocket money in each person alone', () async {
      final t = await layout();
      await spend(t.wifePocket, 1000);
      await spend(t.kidsPocket, 800);

      await CategoryTidy(db).run();

      expect((await row(t.wifePocket)).isArchived, isFalse);
      expect((await row(t.kidsPocket)).isArchived, isFalse);
    });

    test('moves a repeat\'s own sub-category into the place', () async {
      final t = await layout();
      final checkup = await insertTestCategory(
        db,
        name: 'Checkup',
        parentId: t.wifeDoctor,
      );

      await CategoryTidy(db).personRepeats();

      expect((await row(checkup)).parentId, t.doctorVisit);
      expect((await row(checkup)).isArchived, isFalse);
    });

    test('moves Jewellery to Shopping, not Gifts', () async {
      final t = await layout();
      final jewel = await insertTestCategory(
        db,
        name: 'Jewellery',
        parentId: t.wife,
      );
      final tx = await spend(jewel, 5000);

      await CategoryTidy(db).personRepeats();

      expect((await db.transactionsDao.getById(tx))!.categoryId, t.jewellery);
    });

    test('keeps a repeat whose place is gone', () async {
      final family = await insertTestCategory(db, name: 'Family & gifts');
      final wife = await insertTestCategory(db, name: 'Wife', parentId: family);
      final medicine = await insertTestCategory(
        db,
        name: 'Medicine',
        parentId: wife,
      );

      final result = await CategoryTidy(db).personRepeats();

      expect(result.isEmpty, isTrue);
      expect((await row(medicine)).isArchived, isFalse);
    });

    test(
      'does nothing without the Family group, and a second run finds nothing',
      () async {
        expect((await CategoryTidy(db).personRepeats()).isEmpty, isTrue);

        await layout();
        await CategoryTidy(db).run();
        expect((await CategoryTidy(db).run()).isEmpty, isTrue);
      },
    );
  });

  group('look-alikes in other layers', () {
    test('folds the same words into the one closest to the top', () async {
      final shopping = await insertTestCategory(db, name: 'Shopping');
      final top = await insertTestCategory(db, name: 'Gifts');
      final deep = await insertTestCategory(
        db,
        name: 'Gift',
        parentId: shopping,
      );
      final tx = await spend(deep, 500);

      final result = await CategoryTidy(db).mergeLookalikes();

      expect(result.merged, 1);
      expect(result.transactions, 1);
      expect((await db.transactionsDao.getById(tx))!.categoryId, top);
      expect((await row(deep)).isArchived, isTrue);
      expect((await row(top)).isArchived, isFalse);
    });

    test('is not put off by "&", "and", order, case or a plural s', () async {
      final health = await insertTestCategory(db, name: 'Health');
      final a = await insertTestCategory(db, name: 'Medicine & doctor');
      final b = await insertTestCategory(
        db,
        name: 'DOCTOR and medicines',
        parentId: health,
      );

      await CategoryTidy(db).mergeLookalikes();

      expect((await row(a)).isArchived, isFalse);
      expect((await row(b)).isArchived, isTrue);
    });

    test('as high up, the one with more entries stays', () async {
      final quiet = await insertTestCategory(db, name: 'Bills');
      final busy = await insertTestCategory(db, name: 'Bill');
      await spend(busy, 100);
      await spend(busy, 100);

      await CategoryTidy(db).mergeLookalikes();

      expect((await row(busy)).isArchived, isFalse);
      expect((await row(quiet)).isArchived, isTrue);
    });

    test('moves what is inside the one that goes', () async {
      final shopping = await insertTestCategory(db, name: 'Shopping');
      final top = await insertTestCategory(db, name: 'Gifts');
      final deep = await insertTestCategory(
        db,
        name: 'Gift',
        parentId: shopping,
      );
      final inner = await insertTestCategory(
        db,
        name: 'Birthday',
        parentId: deep,
      );

      await CategoryTidy(db).mergeLookalikes();

      expect((await row(inner)).parentId, top);
    });

    test('keeps expense and income apart', () async {
      final group = await insertTestCategory(db, name: 'Other things');
      await insertTestCategory(db, name: 'Gifts', parentId: group);
      await insertTestCategory(db, name: 'Gift', type: CategoryType.income);

      expect((await CategoryTidy(db).mergeLookalikes()).isEmpty, isTrue);
    });

    test(
      'leaves "Other" alone, it means a different thing in each place',
      () async {
        final kitchen = await insertTestCategory(db, name: 'Kitchen');
        final travel = await insertTestCategory(db, name: 'Travel');
        await insertTestCategory(db, name: 'Other', parentId: kitchen);
        await insertTestCategory(db, name: 'Other', parentId: travel);
        await insertTestCategory(db, name: 'Others', parentId: travel);

        expect((await CategoryTidy(db).mergeLookalikes()).isEmpty, isTrue);
      },
    );

    test('leaves a group and its own part alone', () async {
      final group = await insertTestCategory(db, name: 'Gifts');
      final part = await insertTestCategory(db, name: 'Gift', parentId: group);

      expect((await CategoryTidy(db).mergeLookalikes()).isEmpty, isTrue);
      expect((await row(part)).isArchived, isFalse);
    });

    test('leaves what is inside a person group to that step', () async {
      final family = await insertTestCategory(db, name: 'Family & gifts');
      final wife = await insertTestCategory(db, name: 'Wife', parentId: family);
      final kids = await insertTestCategory(
        db,
        name: 'Children',
        parentId: family,
      );
      await insertTestCategory(db, name: 'Gifts');
      final inWife = await insertTestCategory(
        db,
        name: 'Gifts',
        parentId: wife,
      );
      final pocketA = await insertTestCategory(
        db,
        name: 'Pocket money',
        parentId: wife,
      );
      final pocketB = await insertTestCategory(
        db,
        name: 'Pocket money',
        parentId: kids,
      );

      expect((await CategoryTidy(db).mergeLookalikes()).isEmpty, isTrue);
      for (final id in [inWife, pocketA, pocketB]) {
        expect((await row(id)).isArchived, isFalse);
      }
    });

    test('names that only share a word are not touched', () async {
      await insertTestCategory(db, name: 'Bus & rickshaw');
      await insertTestCategory(db, name: 'Bus');

      expect((await CategoryTidy(db).mergeLookalikes()).isEmpty, isTrue);
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
