import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/category_fixes.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/categories/data/category_mapper.dart';
import 'package:hishab/features/categories/data/category_pack.dart';
import 'package:hishab/features/categories/data/default_categories.dart';
import 'package:hishab/features/categories/data/legacy_defaults.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';
import 'package:drift/drift.dart' show Value;

import '../../helpers/test_database.dart';

void main() {
  test('moves Kids pocket money into Children as Pocket money', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final family = await insertTestCategory(db, name: 'Family & gifts');
    final children = await insertTestCategory(
      db,
      name: 'Children',
      parentId: family,
    );
    final kid = await insertTestCategory(
      db,
      name: 'Kids pocket money',
      parentId: family,
    );

    await moveKidsPocketMoney(db);

    final moved = (await db.categoriesDao.getById(kid))!;
    expect(moved.parentId, children);
    expect(moved.name, 'Pocket money');
  });

  test('keeps the old name when Children already has a Pocket money', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final family = await insertTestCategory(db, name: 'Family & gifts');
    final children = await insertTestCategory(
      db,
      name: 'Children',
      parentId: family,
    );
    await insertTestCategory(db, name: 'Pocket money', parentId: children);
    final kid = await insertTestCategory(
      db,
      name: 'Kids pocket money',
      parentId: family,
    );

    await moveKidsPocketMoney(db);

    final moved = (await db.categoriesDao.getById(kid))!;
    expect(moved.parentId, children);
    expect(moved.name, 'Kids pocket money');
  });

  test('leaves things alone when the person changed the layout', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final family = await insertTestCategory(db, name: 'Family & gifts');
    final kid = await insertTestCategory(
      db,
      name: 'Kids pocket money',
      parentId: family,
    );

    await moveKidsPocketMoney(db);

    final same = (await db.categoriesDao.getById(kid))!;
    expect(same.parentId, family);
    expect(same.name, 'Kids pocket money');
  });

  test('each thing is in one place and nothing is two things at once', () {
    for (final roots in [defaultExpenseCategories, defaultIncomeCategories]) {
      final entries = flattenDefaults(roots);
      final paths = entries.map((e) => e.path.join(' > ')).toList();
      // No category appears twice at the same place.
      expect(paths.toSet(), hasLength(paths.length));

      // A name with "&" is a group of the things it names, not one category.
      final withChildren = {
        for (final e in entries)
          if (e.path.length > 1) e.parentPath.join(' > '),
      };
      for (final e in entries) {
        if (e.name.contains(' & ')) {
          expect(
            withChildren,
            contains(e.path.join(' > ')),
            reason: '${e.name} should be split',
          );
        }
      }

      // The same name is not used for different things (Children is a group
      // and a pocket-money person on purpose).
      // The people of the house each hold their own Clothes, Gifts...: the
      // path tells them apart.
      const people = {'Wife', 'Husband', 'Children'};
      final leaves = [
        for (final e in entries)
          if (!withChildren.contains(e.path.join(' > ')) &&
              !(e.path.length == 3 &&
                  e.path.first == 'Family & gifts' &&
                  people.contains(e.path[1])))
            e.name.toLowerCase(),
      ];
      expect(
        leaves.where((n) => leaves.where((m) => m == n).length > 1).toSet(),
        isEmpty,
      );
    }
    final paths = flattenDefaults(defaultExpenseCategories)
        .map((e) => e.path.join(' > '))
        .toList();
    expect(paths, contains('Family & gifts > Children > Pocket money'));
    expect(paths, contains('Family & gifts > Wife > Clothes'));
    expect(paths, isNot(contains('Family & gifts > Pocket money')));
    expect(paths, contains('Shopping > Clothing > Kids wear'));
    expect(paths, isNot(contains('Family & gifts > Kids pocket money')));
  });

  group('refreshDefaultCategories (schema 19)', () {
    /// An install made before the split: the old default tree.
    Future<Map<String, int>> oldInstall(AppDatabase db) async {
      final ids = <String, int>{};
      for (final path in legacyExpensePaths) {
        final names = path.split(' > ');
        ids[path] = await insertTestCategory(
          db,
          name: names.last,
          parentId: names.length == 1
              ? null
              : ids[names.take(names.length - 1).join(' > ')],
        );
      }
      return ids;
    }

    Future<Map<String, bool>> activeByPath(AppDatabase db) async {
      final rows = await db.categoriesDao.getAll(includeArchived: true);
      final domain = [for (final r in rows) r.toDomain()];
      final byId = {for (final c in domain) c.id: c};
      return {
        for (final c in domain)
          if (c.type == CategoryType.expense)
            pathOf(c, byId).join(' > '): !c.isArchived,
      };
    }

    test(
      'archives an unused combined category and adds the split ones',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);
        await oldInstall(db);

        await refreshDefaultCategories(db);

        final state = await activeByPath(db);
        expect(state['Transport > City travel > Bus & rickshaw'], isFalse);
        expect(state['Transport > City travel > Bus'], isTrue);
        expect(state['Transport > City travel > Rickshaw'], isTrue);
        expect(state['Food > Groceries > Flour, sugar & salt'], isFalse);
        expect(state['Food > Groceries > Salt'], isTrue);
        expect(state['Family & gifts > Gifts > Birthday gift'], isTrue);
        // What stayed a default is untouched.
        expect(state['Food > Kacha bazar > Fish'], isTrue);
      },
    );

    test('keeps a combined category that has transactions', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final ids = await oldInstall(db);
      final account = await insertTestAccount(db);
      await db.transactionsDao.insertTransaction(
        TransactionsCompanion.insert(
          type: TransactionType.expense,
          amount: 5000,
          accountId: account,
          categoryId: Value(ids['Transport > City travel > Bus & rickshaw']),
          date: DateTime(2026, 10, 5),
        ),
      );

      await refreshDefaultCategories(db);

      final state = await activeByPath(db);
      expect(state['Transport > City travel > Bus & rickshaw'], isTrue);
      // The split ones are there to use from now on.
      expect(state['Transport > City travel > Bus'], isTrue);
    });

    test('keeps a retired group that holds a category of the person', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final ids = await oldInstall(db);
      await insertTestCategory(
        db,
        name: 'Aunt',
        parentId: ids['Family & gifts > In-laws'],
      );

      await refreshDefaultCategories(db);

      final state = await activeByPath(db);
      expect(state['Family & gifts > In-laws'], isTrue);
      expect(state['Family & gifts > In-laws > Aunt'], isTrue);
    });

    test('running it again changes nothing', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      await oldInstall(db);
      await refreshDefaultCategories(db);
      final first = (await db.categoriesDao.getAll(includeArchived: true))
          .length;

      await refreshDefaultCategories(db);

      expect(
        (await db.categoriesDao.getAll(includeArchived: true)).length,
        first,
      );
    });

    test('leaves an install without the default groups alone', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      await insertTestCategory(db, name: 'Food');
      await insertTestCategory(db, name: 'Mine');

      await refreshDefaultCategories(db);

      expect((await db.categoriesDao.getAll(includeArchived: true)).length, 2);
    });
  });
}
