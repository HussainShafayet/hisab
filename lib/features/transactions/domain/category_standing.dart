import 'package:hishab/features/budget/domain/budget_item.dart';
import 'package:hishab/features/categories/domain/category.dart';

/// How one category stands in one month: what has gone through it so far (it
/// and what is inside it), and the budget that covers it. The entry form shows
/// it so the person sees the situation before saving.
class CategoryStanding {
  const CategoryStanding({required this.total, this.budget});

  /// In poisha: the month's expenses (or income, by the type asked for) in the
  /// category and the categories inside it, as saved now.
  final int total;

  /// The budget of this category, or of the nearest category above it that has
  /// one. Null when none covers it, and for income.
  final BudgetItem? budget;
}

/// The budget that covers [categoryId]: its own, or else the nearest one above
/// it. A budget on a category counts everything inside it, so it covers a
/// category in it too.
BudgetItem? budgetCovering(
  int categoryId,
  Map<int, Category> byId,
  Iterable<BudgetItem> budgets,
) {
  final byCategory = {
    for (final budget in budgets)
      if (budget.categoryId != null) budget.categoryId!: budget,
  };
  final seen = <int>{};
  int? current = categoryId;
  while (current != null && seen.add(current)) {
    final found = byCategory[current];
    if (found != null) return found;
    current = byId[current]?.parentId;
  }
  return null;
}

/// What the entry form says about the category: the money so far, with and
/// without the entry being written, and what is left of the budget.
class StandingLine {
  const StandingLine({
    required this.now,
    required this.after,
    this.budgetName,
    this.budgetLeft,
    this.budgetLeftAfter,
  });

  /// In poisha: this month in the category, without this entry.
  final int now;

  /// In poisha: the same with this entry added.
  final int after;

  /// The covering budget's category, or null when none covers it.
  final String? budgetName;

  /// In poisha: what is left of the budget, without this entry. Negative when
  /// it is already over.
  final int? budgetLeft;

  /// In poisha: what is left with this entry. Negative when it goes over.
  final int? budgetLeftAfter;

  bool get hasEntry => after != now;
}

/// Works out the [StandingLine]. [entry] is the amount being written (zero
/// while empty). [counted] is the part of [standing] that this very entry
/// already makes, when an entry is edited in the same category and month, so
/// it is not counted twice.
StandingLine standingLine(
  CategoryStanding standing, {
  required int entry,
  int counted = 0,
}) {
  final now = standing.total - counted;
  final budget = standing.budget;
  final left = budget == null ? null : budget.limit - (budget.spent - counted);
  return StandingLine(
    now: now,
    after: now + entry,
    budgetName: budget?.categoryName,
    budgetLeft: left,
    budgetLeftAfter: left == null ? null : left - entry,
  );
}
