import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/categories/data/categories_repository.dart';
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

  Future<int> create(
    String name, {
    CategoryType type = CategoryType.expense,
    int? parentId,
  }) => repo.createCategory(
    name: name,
    type: type,
    parentId: parentId,
    icon: 'restaurant',
    color: 0xFFEF5350,
  );

  Future<List<String>> names({bool includeArchived = false}) async {
    final all = await repo
        .watchCategories(includeArchived: includeArchived)
        .first;
    return all.map((c) => c.name).toList();
  }

  group('creating', () {
    test(
      'creates a top-level category with trimmed name, icon and color',
      () async {
        final id = await repo.createCategory(
          name: '  Food  ',
          type: CategoryType.expense,
          icon: 'restaurant',
          color: 0xFFEF5350,
        );

        final category = (await repo.getCategory(id))!;

        expect(category.name, 'Food');
        expect(category.type, CategoryType.expense);
        expect(category.parentId, isNull);
        expect(category.icon, 'restaurant');
        expect(category.color, 0xFFEF5350);
        expect(category.isArchived, isFalse);
      },
    );

    test('puts new categories last among their siblings', () async {
      final first = await create('A');
      final second = await create('B');
      final third = await create('C');
      final child = await create('Child', parentId: first);

      Future<int> orderOf(int id) async =>
          (await repo.getCategory(id))!.sortOrder;
      expect(await orderOf(first), 0);
      expect(await orderOf(second), 1);
      expect(await orderOf(third), 2);
      expect(await orderOf(child), 0);
    });

    test('numbers income and expense categories separately', () async {
      await create('Food');
      final salary = await create('Salary', type: CategoryType.income);

      expect((await repo.getCategory(salary))!.sortOrder, 0);
    });

    test('creates a sub-category under a parent of the same type', () async {
      final food = await create('Food');

      final id = await create('Groceries', parentId: food);

      expect((await repo.getCategory(id))!.parentId, food);
    });

    test('rejects a blank or too long name', () async {
      expect(() => create('  '), throwsValidation('required'));
      expect(() => create('x' * 61), throwsValidation('60'));
    });

    test('rejects a duplicate among siblings, ignoring case', () async {
      final food = await create('Food');
      await create('Groceries', parentId: food);

      expect(() => create(' food '), throwsValidation('already exists'));
      expect(
        () => create('GROCERIES', parentId: food),
        throwsValidation('already exists'),
      );
    });

    test('allows the same name under another parent or type', () async {
      final food = await create('Food');
      final transport = await create('Transport');
      await create('Other', parentId: food);

      await create('Other', parentId: transport);
      await create('Food', type: CategoryType.income);

      expect(await names(), containsAll(['Other', 'Food']));
    });

    test('points to restoring when the duplicate is archived', () async {
      final id = await create('Food');
      await repo.archiveCategory(id);

      expect(() => create('Food'), throwsValidation('Restore it instead'));
    });

    test('allows a sub-category of a sub-category', () async {
      final food = await create('Food');
      final groceries = await create('Groceries', parentId: food);

      final rice = await create('Rice', parentId: groceries);

      expect((await repo.getCategory(rice))!.parentId, groceries);
    });

    test('rejects going deeper than five levels', () async {
      var parent = await create('L1');
      for (final name in ['L2', 'L3', 'L4', 'L5']) {
        parent = await create(name, parentId: parent);
      }

      expect(
        () => create('L6', parentId: parent),
        throwsValidation('5 levels'),
      );
    });

    test(
      'rejects a sub-category with a different type than its parent',
      () async {
        final food = await create('Food');

        expect(
          () => create('Bonus', type: CategoryType.income, parentId: food),
          throwsValidation('same type'),
        );
      },
    );

    test('rejects an archived or missing parent', () async {
      final food = await create('Food');
      await repo.archiveCategory(food);

      expect(
        () => create('Groceries', parentId: food),
        throwsValidation('archived'),
      );
      expect(() => create('X', parentId: 999), throwsValidation('not found'));
    });
  });

  group('updating', () {
    test('changes name, icon and color but not the type', () async {
      final id = await create('Food');

      await repo.updateCategory(
        id,
        name: 'Groceries',
        parentId: null,
        icon: 'shopping_cart',
        color: 0xFF42A5F5,
      );

      final category = (await repo.getCategory(id))!;
      expect(category.name, 'Groceries');
      expect(category.icon, 'shopping_cart');
      expect(category.color, 0xFF42A5F5);
      expect(category.type, CategoryType.expense);
    });

    test('lets a category keep or re-case its own name', () async {
      final id = await create('Food');

      await repo.updateCategory(
        id,
        name: 'FOOD',
        parentId: null,
        icon: 'restaurant',
        color: 0xFFEF5350,
      );

      expect((await repo.getCategory(id))!.name, 'FOOD');
    });

    test('rejects a name that a sibling already has', () async {
      await create('Food');
      final rent = await create('Rent');

      expect(
        () => repo.updateCategory(
          rent,
          name: 'food',
          parentId: null,
          icon: 'home',
          color: 0xFF8D6E63,
        ),
        throwsValidation('already exists'),
      );
    });

    test(
      'moves a category under a parent, last among its new siblings',
      () async {
        final food = await create('Food');
        await create('Groceries', parentId: food);
        final snacks = await create('Snacks');

        await repo.updateCategory(
          snacks,
          name: 'Snacks',
          parentId: food,
          icon: 'restaurant',
          color: 0xFFEF5350,
        );

        final moved = (await repo.getCategory(snacks))!;
        expect(moved.parentId, food);
        expect(moved.sortOrder, 1);
      },
    );

    test('makes a sub-category top-level again', () async {
      final food = await create('Food');
      final groceries = await create('Groceries', parentId: food);

      await repo.updateCategory(
        groceries,
        name: 'Groceries',
        parentId: null,
        icon: 'restaurant',
        color: 0xFFEF5350,
      );

      expect((await repo.getCategory(groceries))!.parentId, isNull);
    });

    test('moves a category together with what is inside it', () async {
      final food = await create('Food');
      final groceries = await create('Groceries', parentId: food);
      final transport = await create('Transport');

      await repo.updateCategory(
        food,
        name: 'Food',
        parentId: transport,
        icon: 'restaurant',
        color: 0xFFEF5350,
      );

      expect((await repo.getCategory(food))!.parentId, transport);
      expect((await repo.getCategory(groceries))!.parentId, food);
    });

    test('rejects moving a category into its own sub-category', () async {
      final food = await create('Food');
      final groceries = await create('Groceries', parentId: food);
      final rice = await create('Rice', parentId: groceries);

      for (final inside in [groceries, rice]) {
        expect(
          () => repo.updateCategory(
            food,
            name: 'Food',
            parentId: inside,
            icon: 'restaurant',
            color: 0xFFEF5350,
          ),
          throwsValidation('own sub-categories'),
        );
      }
    });

    test('rejects a move that would make the tree too deep', () async {
      // Food > Groceries > Rice is three levels tall.
      final food = await create('Food');
      final groceries = await create('Groceries', parentId: food);
      await create('Rice', parentId: groceries);
      var deep = await create('L1');
      for (final name in ['L2', 'L3']) {
        deep = await create(name, parentId: deep);
      }

      expect(
        () => repo.updateCategory(
          food,
          name: 'Food',
          parentId: deep,
          icon: 'restaurant',
          color: 0xFFEF5350,
        ),
        throwsValidation('5 levels'),
      );
    });

    test('can rename a sub-category whose parent is archived', () async {
      final food = await create('Food');
      final groceries = await create('Groceries', parentId: food);
      await repo.archiveCategory(food);

      await repo.updateCategory(
        groceries,
        name: 'Shopping',
        parentId: food,
        icon: 'restaurant',
        color: 0xFFEF5350,
      );

      expect((await repo.getCategory(groceries))!.name, 'Shopping');
    });

    test('rejects itself as parent and a parent of another type', () async {
      final food = await create('Food');
      final salary = await create('Salary', type: CategoryType.income);

      expect(
        () => repo.updateCategory(
          food,
          name: 'Food',
          parentId: food,
          icon: 'restaurant',
          color: 0xFFEF5350,
        ),
        throwsValidation('own parent'),
      );
      expect(
        () => repo.updateCategory(
          food,
          name: 'Food',
          parentId: salary,
          icon: 'restaurant',
          color: 0xFFEF5350,
        ),
        throwsValidation('same type'),
      );
    });

    test('reports a missing category', () async {
      expect(
        () => repo.updateCategory(
          999,
          name: 'x',
          parentId: null,
          icon: 'category',
          color: 0,
        ),
        throwsValidation('not found'),
      );
    });
  });

  group('archiving', () {
    test('hides the category from the default list only', () async {
      final food = await create('Food');
      await create('Rent');

      await repo.archiveCategory(food);

      expect(await names(), ['Rent']);
      expect(await names(includeArchived: true), ['Food', 'Rent']);
      expect((await repo.getCategory(food))!.isArchived, isTrue);
    });

    test('archives the sub-categories with their parent', () async {
      final food = await create('Food');
      await create('Groceries', parentId: food);
      await create('Snacks', parentId: food);
      await create('Rent');

      await repo.archiveCategory(food);

      expect(await names(), ['Rent']);
    });

    test('archives everything inside a category, at any depth', () async {
      final food = await create('Food');
      final groceries = await create('Groceries', parentId: food);
      await create('Rice', parentId: groceries);
      await create('Rent');

      await repo.archiveCategory(food);

      expect(await names(), ['Rent']);
      expect(await names(includeArchived: true), [
        'Food',
        'Groceries',
        'Rice',
        'Rent',
      ]);

      await repo.restoreCategory(food);
      expect(await names(), ['Food', 'Groceries', 'Rice', 'Rent']);
    });

    test('restoring a parent restores its sub-categories', () async {
      final food = await create('Food');
      await create('Groceries', parentId: food);
      await repo.archiveCategory(food);

      await repo.restoreCategory(food);

      expect(await names(), ['Food', 'Groceries']);
    });

    test('archives and restores a single sub-category', () async {
      final food = await create('Food');
      final groceries = await create('Groceries', parentId: food);

      await repo.archiveCategory(groceries);
      expect(await names(), ['Food']);

      await repo.restoreCategory(groceries);
      expect(await names(), ['Food', 'Groceries']);
    });

    test(
      'cannot restore a sub-category while its parent is archived',
      () async {
        final food = await create('Food');
        final groceries = await create('Groceries', parentId: food);
        await repo.archiveCategory(food);

        expect(
          () => repo.restoreCategory(groceries),
          throwsValidation('Restore "Food" first'),
        );
      },
    );

    test('reports a missing category', () async {
      expect(() => repo.archiveCategory(999), throwsValidation('not found'));
      expect(() => repo.restoreCategory(999), throwsValidation('not found'));
    });
  });
}
