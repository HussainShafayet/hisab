import 'package:hishab/features/categories/domain/category.dart';

/// How often and how recently a category was used.
class CategoryUsage {
  const CategoryUsage({required this.count, required this.lastUsed});

  final int count;
  final DateTime lastUsed;
}

/// Orders [categories] for the quick-pick chips: most used first, ties broken
/// by most recently used. Categories that were never used keep their original
/// order and come last.
List<Category> sortCategoriesByUsage(
  List<Category> categories,
  Map<int, CategoryUsage> usage,
) {
  // List.sort is not guaranteed to be stable, so the position is the
  // last tie-breaker.
  final indexed = [
    for (var i = 0; i < categories.length; i++)
      (index: i, category: categories[i]),
  ];
  indexed.sort((a, b) {
    final usedA = usage[a.category.id];
    final usedB = usage[b.category.id];
    final byCount = (usedB?.count ?? 0).compareTo(usedA?.count ?? 0);
    if (byCount != 0) return byCount;
    if (usedA != null && usedB != null) {
      final byRecent = usedB.lastUsed.compareTo(usedA.lastUsed);
      if (byRecent != 0) return byRecent;
    }
    return a.index.compareTo(b.index);
  });
  return [for (final entry in indexed) entry.category];
}
