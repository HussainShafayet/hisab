import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_type.dart';

/// How many levels categories can go: a top-level one is level 1, so with 5
/// there can be a category inside a category inside a category, four deep
/// under the top. More than that is hard to read on a phone.
const maxCategoryDepth = 5;

/// A category with the categories inside it, to any depth.
class CategoryNode {
  const CategoryNode({required this.category, required this.children});

  final Category category;
  final List<CategoryNode> children;
}

/// A category in a flat, depth-first list, with how deep it sits (0 for a
/// top-level one).
typedef CategoryRowInTree = ({Category category, int depth});

int _compare(Category a, Category b) {
  final byOrder = a.sortOrder.compareTo(b.sortOrder);
  return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
}

/// Groups a flat list into a tree, siblings sorted by `sortOrder` then id. A
/// category whose parent is not in [categories] is shown as a top-level one
/// instead of disappearing, and so is one caught in a loop (which the rules
/// do not allow, but a damaged database must not hide money).
List<CategoryNode> buildCategoryTree(Iterable<Category> categories) {
  final list = categories.toList();
  final ids = {for (final c in list) c.id};
  final roots = <Category>[];
  final childrenByParent = <int, List<Category>>{};
  for (final category in list) {
    final parentId = category.parentId;
    if (parentId != null && ids.contains(parentId) && parentId != category.id) {
      childrenByParent.putIfAbsent(parentId, () => []).add(category);
    } else {
      roots.add(category);
    }
  }

  final seen = <int>{};
  CategoryNode? build(Category category) {
    if (!seen.add(category.id)) return null;
    final children = [
      for (final child
          in (childrenByParent[category.id] ?? <Category>[])..sort(_compare))
        ?build(child),
    ];
    return CategoryNode(category: category, children: children);
  }

  final nodes = [for (final root in roots..sort(_compare)) ?build(root)];
  // Anything left over is in a loop with no way in from the top.
  final loose = [
    for (final c in list)
      if (!seen.contains(c.id)) c,
  ]..sort(_compare);
  for (final category in loose) {
    final node = build(category);
    if (node != null) nodes.add(node);
  }
  return nodes;
}

/// The tree as one list, each category followed by everything inside it.
List<Category> flattenCategoryTree(List<CategoryNode> nodes) => [
  for (final row in flattenCategoryTreeWithDepth(nodes)) row.category,
];

/// Like [flattenCategoryTree], with the depth of each category, for drawing
/// the indentation.
List<CategoryRowInTree> flattenCategoryTreeWithDepth(
  List<CategoryNode> nodes, [
  int depth = 0,
]) => [
  for (final node in nodes) ...[
    (category: node.category, depth: depth),
    ...flattenCategoryTreeWithDepth(node.children, depth + 1),
  ],
];

/// The names from the top-level category down to [category], for example
/// `['Food', 'Restaurant', 'Dinner']`. A missing parent ends the path.
List<String> categoryPathNames(Category category, Map<int, Category> byId) {
  final names = <String>[];
  final seen = <int>{};
  Category? current = category;
  while (current != null && seen.add(current.id)) {
    names.add(current.name);
    final parentId = current.parentId;
    current = parentId == null ? null : byId[parentId];
  }
  return names.reversed.toList();
}

/// `Food › Restaurant › Dinner`, or just `Dinner` for a top-level category.
String categoryPathLabel(
  Category category,
  Map<int, Category> byId, {
  String separator = ' › ',
}) => categoryPathNames(category, byId).join(separator);

/// The ids of [id] and every category inside it, at any depth.
Set<int> categoryAndDescendantIds(int id, Iterable<Category> categories) {
  final childrenByParent = <int, List<int>>{};
  for (final category in categories) {
    final parentId = category.parentId;
    if (parentId != null) {
      childrenByParent.putIfAbsent(parentId, () => []).add(category.id);
    }
  }
  final result = <int>{};
  final pending = [id];
  while (pending.isNotEmpty) {
    final next = pending.removeLast();
    if (!result.add(next)) continue;
    pending.addAll(childrenByParent[next] ?? const []);
  }
  return result;
}

/// How many levels [id] sits at: 1 for a top-level category.
int categoryLevel(int id, Map<int, Category> byId) {
  var level = 0;
  final seen = <int>{};
  int? current = id;
  while (current != null && seen.add(current)) {
    final category = byId[current];
    if (category == null) break;
    level++;
    current = category.parentId;
  }
  return level;
}

/// How many levels the tree under [id] has, counting [id] itself: 1 for a
/// category with nothing inside it.
int categoryHeight(int id, Iterable<Category> categories) {
  final childrenByParent = <int, List<int>>{};
  for (final category in categories) {
    final parentId = category.parentId;
    if (parentId != null) {
      childrenByParent.putIfAbsent(parentId, () => []).add(category.id);
    }
  }
  int height(int node, Set<int> path) {
    if (!path.add(node)) return 0;
    var deepest = 0;
    for (final child in childrenByParent[node] ?? const <int>[]) {
      final h = height(child, path);
      if (h > deepest) deepest = h;
    }
    path.remove(node);
    return deepest + 1;
  }

  return height(id, <int>{});
}

/// Why a category cannot go under [parentId], or null when it can. Pass
/// [categoryId] when an existing category is being moved (null when creating
/// one) and [parentId] null for "top level", which always works.
///
/// A category cannot go inside itself or anything inside it, must have the
/// same [type] as its parent, cannot go under an archived parent, and the
/// whole tree must stay within [maxCategoryDepth] levels.
String? categoryParentProblem({
  required Iterable<Category> all,
  required CategoryType type,
  required int? parentId,
  int? categoryId,
}) {
  if (parentId == null) return null;
  final list = all.toList();
  final byId = {for (final c in list) c.id: c};
  final parent = byId[parentId];
  if (parent == null) return tr('Category not found.');
  if (categoryId != null &&
      categoryAndDescendantIds(categoryId, list).contains(parentId)) {
    return categoryId == parentId
        ? tr('A category cannot be its own parent.')
        : tr('A category cannot go inside one of its own sub-categories.');
  }
  if (parent.type != type) {
    return tr('A sub-category must have the same type as its parent.');
  }
  if (parent.isArchived) return tr('The parent category is archived.');

  final inside = categoryId == null ? 1 : categoryHeight(categoryId, list);
  if (categoryLevel(parentId, byId) + inside > maxCategoryDepth) {
    return tr('Categories can go {levels} levels deep at most.', {
      'levels': maxCategoryDepth,
    });
  }
  return null;
}

/// Every node of the tree, each followed by everything inside it.
List<CategoryNode> flattenNodes(List<CategoryNode> nodes) => [
  for (final node in nodes) ...[node, ...flattenNodes(node.children)],
];
