import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/categories/domain/category_type.dart';

Category category(int id, {int? parentId, int sortOrder = 0}) => Category(
  id: id,
  name: 'C$id',
  type: CategoryType.expense,
  parentId: parentId,
  icon: 'category',
  color: 0xFF9E9E9E,
  isArchived: false,
  sortOrder: sortOrder,
);

void main() {
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
    expect(tree[0].children.map((c) => c.id), [2, 4]);
    expect(tree[1].children, isEmpty);
  });

  test('sorts by sort order, then id, at both levels', () {
    final tree = buildCategoryTree([
      category(1, sortOrder: 2),
      category(2, sortOrder: 1),
      category(3, sortOrder: 1),
      category(4, parentId: 1, sortOrder: 5),
      category(5, parentId: 1, sortOrder: 0),
    ]);

    expect(tree.map((n) => n.category.id), [2, 3, 1]);
    expect(tree.last.children.map((c) => c.id), [5, 4]);
  });

  test('shows a sub-category without its parent as a top-level one', () {
    final tree = buildCategoryTree([category(2, parentId: 99)]);

    expect(tree.single.category.id, 2);
    expect(tree.single.children, isEmpty);
  });
}
