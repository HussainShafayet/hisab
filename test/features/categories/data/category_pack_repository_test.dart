import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/categories/data/categories_repository.dart';
import 'package:hishab/features/categories/data/category_pack.dart';
import 'package:hishab/features/categories/data/default_categories.dart';
import 'package:hishab/features/categories/data/category_mapper.dart';
import 'package:hishab/features/categories/domain/category_type.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late CategoriesRepository repo;

  setUp(() {
    db = createTestDatabase();
    repo = CategoriesRepository(db);
  });
  tearDown(() => db.close());

  Future<List<CategoryRow>> rows() =>
      db.categoriesDao.getAll(includeArchived: true);

  test('a fresh install already has them all', () async {
    final seeded = createTestDatabase(seedDefaults: true);
    addTearDown(seeded.close);

    expect(await CategoriesRepository(seeded).addMissingDefaults(), 0);
  });

  test('an install with a few categories gets the rest', () async {
    final food = await insertTestCategory(db, name: 'Food');
    await insertTestCategory(db, name: 'Groceries', parentId: food);
    await insertTestCategory(db, name: 'Salary', type: CategoryType.income);

    final added = await repo.addMissingDefaults();

    final all = await rows();
    expect(all.length, 3 + added);
    expect(added, greaterThan(150));
    // Nothing that was there is touched.
    expect(all.where((c) => c.name == 'Food'), hasLength(1));
    expect(all.where((c) => c.name == 'Groceries'), hasLength(1));
    expect(all.where((c) => c.name == 'Salary'), hasLength(1));
    // New groups sit inside the existing parent, and go down further.
    final bazar = all.singleWhere((c) => c.name == 'Kacha bazar');
    expect(bazar.parentId, food);
    expect(bazar.icon, 'shopping_cart');
    final fish = all.singleWhere((c) => c.name == 'Fish');
    expect(fish.parentId, bazar.id);
    // What goes inside the existing Groceries is added there.
    final groceries = all.singleWhere((c) => c.name == 'Groceries');
    expect(
      all.where((c) => c.parentId == groceries.id).map((c) => c.name),
      contains('Rice (chal)'),
    );
    // A new top-level group comes with everything inside it.
    final help = all.singleWhere((c) => c.name == 'House help & repairs');
    expect(help.parentId, isNull);
    expect(
      all.where((c) => c.parentId == help.id).map((c) => c.name),
      containsAll(['Maid (bua)', 'Repairs']),
    );
  });

  test('asking again adds nothing', () async {
    await insertTestCategory(db, name: 'Food');
    await repo.addMissingDefaults();
    final before = (await rows()).length;

    expect(await repo.addMissingDefaults(), 0);
    expect((await rows()).length, before);
  });

  test('new categories go after the ones that are there', () async {
    final food = await insertTestCategory(db, name: 'Food');
    final first = await insertTestCategory(
      db,
      name: 'Groceries',
      parentId: food,
    );
    await repo.addMissingDefaults();

    final inside = (await rows()).where((c) => c.parentId == food).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    expect(inside.first.id, first);
    expect(inside.map((c) => c.sortOrder).toSet(), hasLength(inside.length));
  });

  test('does not bring back what was archived', () async {
    final food = await insertTestCategory(db, name: 'Food');
    final bazar = await insertTestCategory(
      db,
      name: 'Kacha bazar',
      parentId: food,
    );
    await db.categoriesDao.setArchived(bazar, archived: true);

    await repo.addMissingDefaults();

    final all = await rows();
    expect(all.where((c) => c.name == 'Kacha bazar'), hasLength(1));
    expect(all.singleWhere((c) => c.name == 'Kacha bazar').isArchived, isTrue);
    // Nothing is made inside it either.
    expect(all.where((c) => c.parentId == bazar), isEmpty);
    expect(all.where((c) => c.name == 'Fish'), isEmpty);
  });

  test('every default can be created through the pack', () async {
    await repo.addMissingDefaults();
    final all = await rows();

    expect(
      all.length,
      flattenDefaults(defaultExpenseCategories).length +
          flattenDefaults(defaultIncomeCategories).length,
    );
    expect(missingDefaults(all.map((r) => r.toDomain())), isEmpty);
  });

  test('gives the same tree as a fresh install', () async {
    final seeded = createTestDatabase(seedDefaults: true);
    addTearDown(seeded.close);
    await repo.addMissingDefaults();

    Future<List<String>> shape(AppDatabase d) async {
      final all = await d.categoriesDao.getAll(includeArchived: true);
      final byId = {for (final c in all) c.id: c};
      return [
        for (final c in all)
          '${c.type.name}:${pathKey(pathOf(c.toDomain(), {for (final e in byId.entries) e.key: e.value.toDomain()}))}:${c.icon}:${c.color}',
      ]..sort();
    }

    expect(await shape(db), await shape(seeded));
  });
}
