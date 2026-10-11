import 'package:hishab/features/categories/domain/category.dart';

/// A top-level category with its sub-categories.
class CategoryNode {
  const CategoryNode({required this.category, required this.children});

  final Category category;
  final List<Category> children;
}

/// Groups a flat list into parents with their children, both sorted by
/// `sortOrder` then id. A sub-category whose parent is not in [categories]
/// is shown as a top-level one instead of disappearing.
List<CategoryNode> buildCategoryTree(Iterable<Category> categories) {
  int compare(Category a, Category b) {
    final byOrder = a.sortOrder.compareTo(b.sortOrder);
    return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
  }

  final ids = {for (final c in categories) c.id};
  final roots = <Category>[];
  final childrenByParent = <int, List<Category>>{};
  for (final category in categories) {
    final parentId = category.parentId;
    if (parentId != null && ids.contains(parentId)) {
      childrenByParent.putIfAbsent(parentId, () => []).add(category);
    } else {
      roots.add(category);
    }
  }

  roots.sort(compare);
  return [
    for (final root in roots)
      CategoryNode(
        category: root,
        children: (childrenByParent[root.id] ?? <Category>[])..sort(compare),
      ),
  ];
}
