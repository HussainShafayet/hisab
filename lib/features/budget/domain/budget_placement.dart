import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';

/// Where a category budget sits in the category tree, so two budgets with the
/// same name (like "Gifts" under In-laws and under Brothers & sisters) can be
/// told apart, and a budget whose spending also counts in a bigger one says
/// so.
class BudgetPlacement {
  const BudgetPlacement({
    this.parentPath,
    this.countedIn,
    this.countedInId,
    this.insideLimits = 0,
  });

  /// The categories it sits inside, like `Family & gifts › In-laws`, or null
  /// for a top-level category.
  final String? parentPath;

  /// The name of the nearest category above it that has its own budget this
  /// month: its spending is counted there too. Null when there is none.
  final String? countedIn;

  /// The category id of [countedIn].
  final int? countedInId;

  /// In poisha: the limits of the budgets right inside this one (the ones
  /// whose [countedIn] is this category) added up. Zero when there are none.
  final int insideLimits;

  /// The budgets inside ask for more than [limit]: they cannot all be met.
  bool insideOver(int limit) => insideLimits > limit;

  BudgetPlacement withInsideLimits(int total) => BudgetPlacement(
    parentPath: parentPath,
    countedIn: countedIn,
    countedInId: countedInId,
    insideLimits: total,
  );
}

/// The [BudgetPlacement] of every category budget in [limits] (category id to
/// limit), with [BudgetPlacement.insideLimits] filled in.
Map<int, BudgetPlacement> budgetPlacements(
  Map<int, int> limits,
  Map<int, Category> byId,
) {
  final budgeted = limits.keys.toSet();
  final result = {
    for (final id in budgeted) id: budgetPlacement(id, byId, budgeted),
  };
  final inside = <int, int>{};
  for (final MapEntry(key: id, value: placement) in result.entries) {
    final above = placement.countedInId;
    if (above != null) inside[above] = (inside[above] ?? 0) + limits[id]!;
  }
  return {
    for (final MapEntry(key: id, value: placement) in result.entries)
      id: placement.withInsideLimits(inside[id] ?? 0),
  };
}

/// Works out the [BudgetPlacement] of the budget of [categoryId], given every
/// category by id and the ids of the categories that have a budget this month.
BudgetPlacement budgetPlacement(
  int categoryId,
  Map<int, Category> byId,
  Set<int> budgeted,
) {
  final category = byId[categoryId];
  if (category == null) return const BudgetPlacement();
  final path = categoryPathNames(category, byId);
  String? countedIn;
  int? countedInId;
  final seen = <int>{categoryId};
  var parentId = category.parentId;
  while (parentId != null && seen.add(parentId)) {
    final parent = byId[parentId];
    if (parent == null) break;
    if (budgeted.contains(parent.id)) {
      countedIn = parent.name;
      countedInId = parent.id;
      break;
    }
    parentId = parent.parentId;
  }
  return BudgetPlacement(
    parentPath: path.length > 1
        ? path.sublist(0, path.length - 1).join(' › ')
        : null,
    countedIn: countedIn,
    countedInId: countedInId,
  );
}
