import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/reports/domain/category_branch.dart';

Category cat(int id, String name, {int? parentId, int order = 0}) => Category(
  id: id,
  name: name,
  type: CategoryType.expense,
  parentId: parentId,
  icon: 'category',
  color: 0xFF000000,
  isArchived: false,
  sortOrder: order,
);

// Food(1) > Kacha bazar(2) > Fish(3), Vegetables(4); Food > Tea(5); Rent(6).
final tree = [
  cat(1, 'Food'),
  cat(2, 'Kacha bazar', parentId: 1),
  cat(3, 'Fish', parentId: 2),
  cat(4, 'Vegetables', parentId: 2, order: 1),
  cat(5, 'Tea', parentId: 1, order: 1),
  cat(6, 'Rent', order: 1),
];

CategoryBranch branch(List<CategoryBranch> list, String name) =>
    flattenBranches(list).singleWhere((b) => b.category.name == name);

void main() {
  test('rolls the money up: a group is its own money plus what is inside', () {
    final branches = buildBranches(tree, {
      1: 1000, // directly on Food
      3: 20000,
      4: 5000,
      5: 3000,
      6: 40000,
    });

    expect(branch(branches, 'Kacha bazar').total, 25000);
    expect(branch(branches, 'Kacha bazar').own, 0);
    expect(branch(branches, 'Food').own, 1000);
    expect(branch(branches, 'Food').total, 1000 + 25000 + 3000);
    expect(branch(branches, 'Fish').total, 20000);
    expect(branch(branches, 'Rent').total, 40000);
  });

  test('puts the biggest first, at every level', () {
    final branches = buildBranches(tree, {
      3: 20000,
      4: 5000,
      5: 3000,
      6: 40000,
    });

    expect(branches.map((b) => b.category.name), ['Rent', 'Food']);
    final food = branch(branches, 'Food');
    expect(food.children.map((b) => b.category.name), ['Kacha bazar', 'Tea']);
    expect(
      branch(branches, 'Kacha bazar').children.map((b) => b.category.name),
      ['Fish', 'Vegetables'],
    );
  });

  test('leaves out what has no money anywhere inside', () {
    final branches = buildBranches(tree, {4: 5000});

    expect(flattenBranches(branches).map((b) => b.category.name), [
      'Food',
      'Kacha bazar',
      'Vegetables',
    ]);
  });

  test('is empty when there is no money', () {
    expect(buildBranches(tree, {}), isEmpty);
    expect(buildBranches([], {1: 100}), isEmpty);
  });

  test('ties go by name', () {
    final branches = buildBranches(
      [cat(1, 'banana'), cat(2, 'Apple'), cat(3, 'cherry')],
      {1: 100, 2: 100, 3: 100},
    );

    expect(branches.map((b) => b.category.name), ['Apple', 'banana', 'cherry']);
  });

  test('money on a category that is not in the list is not counted', () {
    final branches = buildBranches(tree, {99: 70000, 6: 100});

    expect(branches.single.category.name, 'Rent');
    expect(branches.single.total, 100);
  });

  test('the top level adds up to everything that was spent', () {
    final own = {1: 1000, 3: 20000, 4: 5000, 5: 3000, 6: 40000};
    final branches = buildBranches(tree, own);

    expect(
      branches.fold<int>(0, (sum, b) => sum + b.total),
      own.values.fold<int>(0, (sum, v) => sum + v),
    );
  });

  test('goes down as far as the tree goes', () {
    final deep = [
      cat(1, 'A'),
      cat(2, 'B', parentId: 1),
      cat(3, 'C', parentId: 2),
      cat(4, 'D', parentId: 3),
      cat(5, 'E', parentId: 4),
    ];
    final branches = buildBranches(deep, {5: 700});

    expect(flattenBranches(branches), hasLength(5));
    expect(branch(branches, 'A').total, 700);
  });
}
