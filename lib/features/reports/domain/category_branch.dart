import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';

/// A category with the money in it, and the categories inside it with theirs.
class CategoryBranch {
  const CategoryBranch({
    required this.category,
    required this.own,
    required this.total,
    required this.children,
  });

  final Category category;

  /// What was put directly on this category, in poisha.
  final int own;

  /// [own] plus the total of everything inside it.
  final int total;

  /// The categories inside it that have money, the biggest first.
  final List<CategoryBranch> children;
}

/// Rolls the money up the tree: each category's total is its own money plus
/// that of everything inside it, so Food shows what went to Food itself and to
/// Kacha bazar, Fish and the rest. Categories with no money anywhere inside
/// are left out, and the biggest come first (ties by name).
///
/// [ownById] is what was put directly on each category, by id. Money on a
/// category that is not in [categories] is not counted.
List<CategoryBranch> buildBranches(
  Iterable<Category> categories,
  Map<int, int> ownById,
) {
  CategoryBranch? branch(CategoryNode node) {
    final children = [for (final child in node.children) ?branch(child)]
      ..sort(_biggestFirst);
    final own = ownById[node.category.id] ?? 0;
    final total = own + children.fold<int>(0, (sum, c) => sum + c.total);
    if (total == 0) return null;
    return CategoryBranch(
      category: node.category,
      own: own,
      total: total,
      children: children,
    );
  }

  return [for (final node in buildCategoryTree(categories)) ?branch(node)]
    ..sort(_biggestFirst);
}

int _biggestFirst(CategoryBranch a, CategoryBranch b) {
  final byTotal = b.total.compareTo(a.total);
  if (byTotal != 0) return byTotal;
  return a.category.name.toLowerCase().compareTo(b.category.name.toLowerCase());
}

/// The branches and everything inside them in a flat list, depth first.
List<CategoryBranch> flattenBranches(List<CategoryBranch> branches) => [
  for (final b in branches) ...[b, ...flattenBranches(b.children)],
];
