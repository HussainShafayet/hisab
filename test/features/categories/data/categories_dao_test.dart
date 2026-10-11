import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/categories/domain/category_type.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  test('stores and reads a category, with defaults', () async {
    final id = await insertTestCategory(db, name: 'Food');

    final category = (await db.categoriesDao.getById(id))!;

    expect(category.name, 'Food');
    expect(category.type, CategoryType.expense);
    expect(category.parentId, isNull);
    expect(category.icon, 'category');
    expect(category.color, 0xFF9E9E9E);
    expect(category.isArchived, isFalse);
    expect(category.sortOrder, 0);
  });

  test('filters by type', () async {
    await insertTestCategory(db, name: 'Food');
    await insertTestCategory(db, name: 'Salary', type: CategoryType.income);

    final expense = await db.categoriesDao.getAll(type: CategoryType.expense);
    final income = await db.categoriesDao.getAll(type: CategoryType.income);
    final both = await db.categoriesDao.getAll();

    expect(expense.map((c) => c.name), ['Food']);
    expect(income.map((c) => c.name), ['Salary']);
    expect(both, hasLength(2));
  });

  test('orders by sort order, then by id', () async {
    Future<void> add(String name, int order) => db.categoriesDao.insertCategory(
      CategoriesCompanion.insert(
        name: name,
        type: CategoryType.expense,
        sortOrder: Value(order),
      ),
    );
    await add('C', 2);
    await add('A', 1);
    await add('B', 1);

    final names = (await db.categoriesDao.getAll()).map((c) => c.name);

    expect(names, ['A', 'B', 'C']);
  });

  test('keeps the parent link of a sub-category', () async {
    final parent = await insertTestCategory(db, name: 'Food');
    final child = await insertTestCategory(
      db,
      name: 'Groceries',
      parentId: parent,
    );

    expect((await db.categoriesDao.getById(child))!.parentId, parent);
  });

  test('rejects a parent that does not exist', () async {
    expect(
      () => insertTestCategory(db, name: 'Orphan', parentId: 999),
      throwsConstraint('FOREIGN KEY'),
    );
  });

  test('a parent with sub-categories cannot be hard deleted', () async {
    final parent = await insertTestCategory(db, name: 'Food');
    await insertTestCategory(db, name: 'Groceries', parentId: parent);

    expect(
      () => db.delete(db.categories).go(),
      throwsConstraint('FOREIGN KEY'),
    );
  });

  test('archiving hides a category from the default list only', () async {
    final food = await insertTestCategory(db, name: 'Food');
    final rent = await insertTestCategory(db, name: 'Rent');

    await db.categoriesDao.setArchived(rent, archived: true);

    expect((await db.categoriesDao.getAll()).map((c) => c.id), [food]);
    expect(
      (await db.categoriesDao.getAll(includeArchived: true)).map((c) => c.id),
      [food, rent],
    );
  });

  test('updateCategory replaces the row', () async {
    final id = await insertTestCategory(db, name: 'Food');
    final category = (await db.categoriesDao.getById(id))!;

    await db.categoriesDao.updateCategory(
      category.copyWith(name: 'Groceries', icon: 'shopping_cart'),
    );

    final reloaded = (await db.categoriesDao.getById(id))!;
    expect(reloaded.name, 'Groceries');
    expect(reloaded.icon, 'shopping_cart');
  });

  group('findOrCreateTopLevel', () {
    test('creates the category once and then finds it', () async {
      final first = await db.categoriesDao.findOrCreateTopLevel(
        'Fees',
        CategoryType.expense,
        icon: 'account_balance',
        color: 0xFF78909C,
      );
      final second = await db.categoriesDao.findOrCreateTopLevel(
        'Fees',
        CategoryType.expense,
        icon: 'account_balance',
      );

      expect(second, first);
      final category = (await db.categoriesDao.getById(first))!;
      expect(category.icon, 'account_balance');
      expect(category.color, 0xFF78909C);
      expect(await db.categoriesDao.getAll(), hasLength(1));
    });

    test('keeps income and expense separate', () async {
      final expense = await db.categoriesDao.findOrCreateTopLevel(
        'Other',
        CategoryType.expense,
        icon: 'x',
      );
      final income = await db.categoriesDao.findOrCreateTopLevel(
        'Other',
        CategoryType.income,
        icon: 'x',
      );

      expect(income, isNot(expense));
    });

    test('finds an archived category and ignores sub-categories', () async {
      final parent = await insertTestCategory(db, name: 'Food');
      await insertTestCategory(db, name: 'Fees', parentId: parent);
      final fees = await insertTestCategory(db, name: 'Fees');
      await db.categoriesDao.setArchived(fees, archived: true);

      final found = await db.categoriesDao.findOrCreateTopLevel(
        'Fees',
        CategoryType.expense,
        icon: 'x',
      );

      expect(found, fees);
    });
  });
}
