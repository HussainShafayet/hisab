import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/categories/domain/category_type.dart';

Category category(
  int id, {
  int? parentId,
  int sortOrder = 0,
  CategoryType type = CategoryType.expense,
  bool isArchived = false,
}) => Category(
  id: id,
  name: 'C$id',
  type: type,
  parentId: parentId,
  icon: 'category',
  color: 0xFF9E9E9E,
  isArchived: isArchived,
  sortOrder: sortOrder,
);

Map<int, Category> byId(List<Category> list) => {for (final c in list) c.id: c};

void main() {
  group('buildCategoryTree', () {
    test('is empty for no categories', () {
      expect(buildCategoryTree([]), isEmpty);
    });

    test('groups sub-categories under their parent', () {
      final tree = buildCategoryTree([
        category(1),
        category(2, parentId: 1),
        category(3),
        category(4, parentId: 1),
      ]);

      expect(tree.map((n) => n.category.id), [1, 3]);
      expect(tree[0].children.map((n) => n.category.id), [2, 4]);
      expect(tree[1].children, isEmpty);
    });

    test('sorts by sort order, then id, at every level', () {
      final tree = buildCategoryTree([
        category(1, sortOrder: 2),
        category(2, sortOrder: 1),
        category(3, sortOrder: 1),
        category(4, parentId: 1, sortOrder: 5),
        category(5, parentId: 1, sortOrder: 0),
      ]);

      expect(tree.map((n) => n.category.id), [2, 3, 1]);
      expect(tree.last.children.map((n) => n.category.id), [5, 4]);
    });

    test('nests as deep as the data goes', () {
      final tree = buildCategoryTree([
        category(3, parentId: 2),
        category(1),
        category(2, parentId: 1),
        category(4, parentId: 3),
      ]);

      expect(tree.single.category.id, 1);
      final second = tree.single.children.single;
      expect(second.category.id, 2);
      final third = second.children.single;
      expect(third.category.id, 3);
      expect(third.children.single.category.id, 4);
    });

    test('shows a sub-category without its parent as a top-level one', () {
      final tree = buildCategoryTree([category(2, parentId: 99)]);

      expect(tree.single.category.id, 2);
      expect(tree.single.children, isEmpty);
    });

    test('does not hang or lose categories that are in a loop', () {
      final tree = buildCategoryTree([
        category(1, parentId: 2),
        category(2, parentId: 1),
        category(3, parentId: 3),
      ]);

      final all = flattenCategoryTree(tree).map((c) => c.id).toList()..sort();
      expect(all, [1, 2, 3]);
    });
  });

  group('flattening', () {
    final tree = buildCategoryTree([
      category(1),
      category(2, parentId: 1),
      category(3),
      category(4, parentId: 3),
      category(5, parentId: 1),
      category(6, parentId: 2),
    ]);

    test(
      'flattenCategoryTree lists each category before what is inside it',
      () {
        expect(flattenCategoryTree(tree).map((c) => c.id), [1, 2, 6, 5, 3, 4]);
        expect(flattenCategoryTree([]), isEmpty);
      },
    );

    test('flattenCategoryTreeWithDepth says how deep each one is', () {
      expect(
        [
          for (final row in flattenCategoryTreeWithDepth(tree))
            (row.category.id, row.depth),
        ],
        [(1, 0), (2, 1), (6, 2), (5, 1), (3, 0), (4, 1)],
      );
    });
  });

  group('flattenNodes', () {
    test('lists every node, each followed by what is inside it', () {
      final tree = buildCategoryTree([
        category(1),
        category(2, parentId: 1),
        category(3, parentId: 2),
        category(4),
      ]);

      expect(flattenNodes(tree).map((n) => n.category.id), [1, 2, 3, 4]);
      expect(flattenNodes([]), isEmpty);
    });
  });

  group('paths', () {
    final list = [
      category(1),
      category(2, parentId: 1),
      category(3, parentId: 2),
    ];

    test('categoryPathNames goes from the top down', () {
      final map = byId(list);
      expect(categoryPathNames(list[2], map), ['C1', 'C2', 'C3']);
      expect(categoryPathNames(list[0], map), ['C1']);
    });

    test('categoryPathLabel joins the names', () {
      final map = byId(list);
      expect(categoryPathLabel(list[2], map), 'C1 › C2 › C3');
      expect(categoryPathLabel(list[2], map, separator: ' > '), 'C1 > C2 > C3');
      expect(categoryPathLabel(list[0], map), 'C1');
    });

    test('a missing parent ends the path', () {
      expect(
        categoryPathNames(category(5, parentId: 99), byId([category(5)])),
        ['C5'],
      );
    });

    test('a loop does not make the path endless', () {
      final loop = [category(1, parentId: 2), category(2, parentId: 1)];
      expect(categoryPathNames(loop[0], byId(loop)).length, 2);
    });
  });

  group('categoryAndDescendantIds', () {
    final list = [
      category(1),
      category(2, parentId: 1),
      category(3, parentId: 2),
      category(4),
      category(5, parentId: 4),
    ];

    test('includes the category and everything inside it', () {
      expect(categoryAndDescendantIds(1, list), {1, 2, 3});
      expect(categoryAndDescendantIds(2, list), {2, 3});
      expect(categoryAndDescendantIds(3, list), {3});
      expect(categoryAndDescendantIds(4, list), {4, 5});
    });

    test('is just the id for a category that is not in the list', () {
      expect(categoryAndDescendantIds(99, list), {99});
    });
  });

  group('levels', () {
    final list = [
      category(1),
      category(2, parentId: 1),
      category(3, parentId: 2),
      category(4),
    ];

    test('categoryLevel is 1 for a top-level category', () {
      final map = byId(list);
      expect(categoryLevel(1, map), 1);
      expect(categoryLevel(2, map), 2);
      expect(categoryLevel(3, map), 3);
      expect(categoryLevel(99, map), 0);
    });

    test(
      'categoryHeight counts the levels under a category, itself included',
      () {
        expect(categoryHeight(1, list), 3);
        expect(categoryHeight(2, list), 2);
        expect(categoryHeight(3, list), 1);
        expect(categoryHeight(4, list), 1);
      },
    );
  });

  group('categoryParentProblem', () {
    // 1 > 2 > 3 > 4 > 5 is five levels, the most there can be.
    final chain = [
      category(1),
      category(2, parentId: 1),
      category(3, parentId: 2),
      category(4, parentId: 3),
      category(5, parentId: 4),
    ];
    final other = category(10);

    String? problem(
      List<Category> all, {
      required int? parentId,
      int? categoryId,
      CategoryType type = CategoryType.expense,
    }) => categoryParentProblem(
      all: all,
      type: type,
      parentId: parentId,
      categoryId: categoryId,
    );

    test('top level always works', () {
      expect(problem(chain, parentId: null), isNull);
      expect(problem(chain, parentId: null, categoryId: 3), isNull);
    });

    test('a new category can go inside a top-level or a sub-category', () {
      expect(problem([...chain, other], parentId: 10), isNull);
      expect(problem(chain, parentId: 3), isNull);
      expect(problem(chain, parentId: 4), isNull);
    });

    test('a new category cannot go below the fifth level', () {
      expect(problem(chain, parentId: 5), contains('5 levels'));
    });

    test('a category cannot go inside itself or something inside it', () {
      expect(
        problem(chain, parentId: 2, categoryId: 2),
        contains('own parent'),
      );
      expect(
        problem(chain, parentId: 4, categoryId: 2),
        contains('own sub-categories'),
      );
    });

    test('moving a category takes its sub-categories along', () {
      // 10 has nothing in it: it fits anywhere above the fifth level.
      expect(problem([...chain, other], parentId: 4, categoryId: 10), isNull);
      // 2 > 3 > 4 > 5 is four levels tall; under level 2 would be six.
      final all = [...chain, other, category(11, parentId: 10)];
      expect(problem(all, parentId: 10, categoryId: 2), isNull);
      expect(problem(all, parentId: 11, categoryId: 2), contains('5 levels'));
    });

    test('the parent must have the same type', () {
      expect(
        problem(chain, parentId: 1, type: CategoryType.income),
        contains('same type'),
      );
    });

    test('the parent must not be archived', () {
      final all = [category(1, isArchived: true)];
      expect(problem(all, parentId: 1), contains('archived'));
    });

    test('a parent that does not exist is refused', () {
      expect(problem(chain, parentId: 99), contains('not found'));
    });
  });
}
