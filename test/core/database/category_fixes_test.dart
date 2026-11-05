import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/category_fixes.dart';
import 'package:hishab/features/categories/data/default_categories.dart';

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

  test('the defaults no longer repeat children things elsewhere', () {
    final paths = flattenDefaults(defaultExpenseCategories)
        .map((e) => e.path.join(' > '))
        .toList();
    expect(paths, contains('Family & gifts > Children > Pocket money'));
    expect(paths, isNot(contains('Family & gifts > Kids pocket money')));
    expect(paths, isNot(contains('Shopping > Clothing > Kids wear')));
    // No category appears twice at the same place.
    expect(paths.toSet(), hasLength(paths.length));
  });
}
