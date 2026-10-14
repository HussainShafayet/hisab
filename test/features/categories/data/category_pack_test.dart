import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/categories/data/category_pack.dart';
import 'package:hishab/features/categories/data/default_categories.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/categories/domain/category_type.dart';

Category cat(
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

/// Food > Kacha bazar > Fish, Food > Tea, and Rent.
const small = [
  DefaultCategory(
    'Food',
    icon: 'restaurant',
    color: 1,
    children: [
      DefaultCategory(
        'Kacha bazar',
        icon: 'shopping_cart',
        children: [DefaultCategory('Fish'), DefaultCategory('Meat')],
      ),
      DefaultCategory('Tea', icon: 'local_cafe'),
    ],
  ),
  DefaultCategory('Rent', icon: 'home', color: 2),
];

List<PlannedCategory> plan(List<Category> existing) =>
    missingDefaults(existing, expense: small, income: const []);

List<String> names(List<PlannedCategory> planned) =>
    planned.map((p) => p.name).toList();

void main() {
  group('flattenDefaults', () {
    test('lists parents before what is inside them, with the paths', () {
      final entries = flattenDefaults(small);

      expect(entries.map((e) => e.path.join(' > ')), [
        'Food',
        'Food > Kacha bazar',
        'Food > Kacha bazar > Fish',
        'Food > Kacha bazar > Meat',
        'Food > Tea',
        'Rent',
      ]);
      expect(entries[2].parentPath, ['Food', 'Kacha bazar']);
      expect(entries.first.parentPath, isEmpty);
    });

    test('hands icon and color down, unless a category has its own', () {
      final entries = {for (final e in flattenDefaults(small)) e.name: e};

      expect(entries['Food']!.icon, 'restaurant');
      expect(entries['Kacha bazar']!.icon, 'shopping_cart');
      expect(entries['Kacha bazar']!.color, 1);
      expect(entries['Fish']!.icon, 'shopping_cart');
      expect(entries['Fish']!.color, 1);
      expect(entries['Tea']!.icon, 'local_cafe');
      expect(entries['Rent']!.color, 2);
    });
  });

  group('missingDefaults', () {
    test('plans everything for an empty install, parents first', () {
      final planned = plan([]);

      expect(names(planned), [
        'Food',
        'Kacha bazar',
        'Fish',
        'Meat',
        'Tea',
        'Rent',
      ]);
      expect(planned.first.parentPath, isEmpty);
      expect(planned[2].parentPath, ['Food', 'Kacha bazar']);
      expect(planned[2].icon, 'shopping_cart');
    });

    test('plans only what is missing, at any depth', () {
      final planned = plan([
        cat(1, 'Food'),
        cat(2, 'Kacha bazar', parentId: 1),
        cat(3, 'Fish', parentId: 2),
        cat(4, 'Rent'),
      ]);

      expect(names(planned), ['Meat', 'Tea']);
      expect(planned.first.parentPath, ['Food', 'Kacha bazar']);
      expect(planned.last.parentPath, ['Food']);
    });

    test('plans the whole branch under a missing group', () {
      final planned = plan([cat(1, 'Food'), cat(4, 'Rent')]);

      expect(names(planned), ['Kacha bazar', 'Fish', 'Meat', 'Tea']);
    });

    test('compares names without case or spaces around them', () {
      final planned = plan([
        cat(1, ' food '),
        cat(2, 'KACHA BAZAR', parentId: 1),
        cat(3, 'fish', parentId: 2),
        cat(5, 'MEAT', parentId: 2),
        cat(6, 'tea', parentId: 1),
        cat(4, 'RENT'),
      ]);

      expect(planned, isEmpty);
    });

    test('goes by where a name sits: Fish somewhere else is not this Fish', () {
      final planned = plan([
        cat(1, 'Food'),
        cat(2, 'Kacha bazar', parentId: 1),
        cat(3, 'Fish', parentId: 1),
        cat(4, 'Rent'),
      ]);

      expect(names(planned), ['Fish', 'Meat', 'Tea']);
      expect(planned.first.parentPath, ['Food', 'Kacha bazar']);
    });

    test('a category that was archived does not come back', () {
      final planned = plan([
        cat(1, 'Food'),
        cat(2, 'Kacha bazar', parentId: 1, archived: true),
        cat(3, 'Tea', parentId: 1),
        cat(4, 'Rent', archived: true),
      ]);

      // Not Kacha bazar, and not Fish or Meat, which would go inside it.
      expect(planned, isEmpty);
    });

    test('an archived name does not hide one that only starts the same', () {
      final planned = plan([
        cat(1, 'Food'),
        cat(2, 'Kacha', parentId: 1, archived: true),
        cat(3, 'Rent'),
      ]);

      expect(names(planned), ['Kacha bazar', 'Fish', 'Meat', 'Tea']);
    });

    test('keeps income and expense apart', () {
      final planned = missingDefaults(
        [cat(1, 'Food', type: CategoryType.income)],
        expense: small,
        income: const [DefaultCategory('Salary', icon: 'payments', color: 3)],
      );

      expect(
        planned.where((p) => p.type == CategoryType.income).map((p) => p.name),
        ['Salary'],
      );
      expect(
        planned.where((p) => p.type == CategoryType.expense),
        hasLength(6),
      );
    });
  });

  group('pathOf', () {
    test('walks up to the top level', () {
      final all = [
        cat(1, 'Food'),
        cat(2, 'Kacha bazar', parentId: 1),
        cat(3, 'Fish', parentId: 2),
      ];
      final byId = {for (final c in all) c.id: c};

      expect(pathOf(all[2], byId), ['Food', 'Kacha bazar', 'Fish']);
      expect(pathOf(all[0], byId), ['Food']);
    });
  });

  group('the real defaults', () {
    final entries = [
      ...flattenDefaults(defaultExpenseCategories),
      ...flattenDefaults(defaultIncomeCategories),
    ];

    test('plan everything for an empty install', () {
      expect(missingDefaults([]), hasLength(entries.length));
      expect(entries.length, greaterThan(150));
    });

    test('go down a few levels but never past the limit', () {
      final deepest = entries
          .map((e) => e.path.length)
          .reduce((a, b) => a > b ? a : b);

      expect(deepest, greaterThanOrEqualTo(3));
      expect(deepest, lessThanOrEqualTo(maxCategoryDepth));
    });

    test('have no name twice inside one parent', () {
      final keys = [
        for (final (type, list) in [
          ('e', defaultExpenseCategories),
          ('i', defaultIncomeCategories),
        ])
          for (final e in flattenDefaults(list)) '$type/${pathKey(e.path)}',
      ];

      expect(keys.toSet(), hasLength(keys.length));
    });

    test('give every category an icon and a color', () {
      for (final e in entries) {
        expect(e.icon, isNotEmpty, reason: e.name);
        expect(e.color, isNonZero, reason: e.name);
      }
    });

    test('keep the busiest groups broad', () {
      final food = flattenDefaults(defaultExpenseCategories)
          .where((e) => e.path.first == 'Food')
          .map((e) => e.path.join(' > '))
          .toSet();

      expect(
        food,
        containsAll(<String>[
          'Food > Kacha bazar > Fish',
          'Food > Kacha bazar > Vegetables',
          'Food > Groceries > Rice (chal)',
          'Food > Snacks & tea > Fuchka & chotpoti',
          'Food > Restaurants > Biryani & kacchi',
        ]),
      );
    });
  });
}
