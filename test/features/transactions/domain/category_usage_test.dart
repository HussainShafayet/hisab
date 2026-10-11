import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/transactions/domain/category_usage.dart';

Category category(int id) => Category(
  id: id,
  name: 'C$id',
  type: CategoryType.expense,
  parentId: null,
  icon: 'category',
  color: 0xFF9E9E9E,
  isArchived: false,
  sortOrder: id,
);

CategoryUsage usage(int count, int day) =>
    CategoryUsage(count: count, lastUsed: DateTime(2026, 10, day));

List<int> ids(List<Category> categories) =>
    categories.map((c) => c.id).toList();

void main() {
  final categories = [for (var i = 1; i <= 5; i++) category(i)];

  test('keeps the original order when nothing was used', () {
    expect(ids(sortCategoriesByUsage(categories, {})), [1, 2, 3, 4, 5]);
  });

  test('puts the most used first', () {
    final sorted = sortCategoriesByUsage(categories, {
      3: usage(10, 1),
      5: usage(2, 9),
      1: usage(4, 5),
    });

    expect(ids(sorted), [3, 1, 5, 2, 4]);
  });

  test('breaks ties by the most recent use', () {
    final sorted = sortCategoriesByUsage(categories, {
      2: usage(3, 1),
      4: usage(3, 9),
      5: usage(3, 5),
    });

    expect(ids(sorted), [4, 5, 2, 1, 3]);
  });

  test('breaks full ties by the original order', () {
    final sorted = sortCategoriesByUsage(categories, {
      5: usage(1, 3),
      2: usage(1, 3),
    });

    expect(ids(sorted), [2, 5, 1, 3, 4]);
  });

  test('does not change the list it was given', () {
    final copy = [...categories];
    sortCategoriesByUsage(categories, {5: usage(9, 1)});

    expect(ids(categories), ids(copy));
  });

  test('ignores usage of categories that are not in the list', () {
    final sorted = sortCategoriesByUsage(categories, {99: usage(50, 1)});

    expect(ids(sorted), [1, 2, 3, 4, 5]);
  });
}
