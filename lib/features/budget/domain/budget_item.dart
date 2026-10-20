import 'package:hishab/features/budget/domain/budget_progress.dart';

/// One budget of a month together with what has been spent against it.
class BudgetItem {
  const BudgetItem({
    required this.id,
    required this.limit,
    required this.spent,
    this.carriedOver = 0,
    this.noCarry = false,
    this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
  });

  final int id;

  /// Null for the overall budget of the month.
  final int? categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final int? categoryColor;

  /// In poisha: the limit that counts this month, which is the amount that was
  /// set plus [carriedOver].
  final int limit;

  /// In poisha: what was left of this budget in the months before and is
  /// added to it (Budget > Carry over what is left). Zero when that is off.
  final int carriedOver;

  /// This budget was set to take nothing from before and pass nothing on.
  final bool noCarry;

  /// In poisha: the amount that was set for this month, without what was
  /// carried over. This is what the edit box starts with.
  int get setAmount => limit - carriedOver;

  /// In poisha: the month's expenses in this category and its
  /// sub-categories, or all expenses for the overall budget. Transfers and
  /// balance adjustments are not spending.
  final int spent;

  BudgetProgress get progress => BudgetProgress(limit: limit, spent: spent);
}

/// All the budgets of one month.
class MonthBudget {
  const MonthBudget({
    required this.month,
    required this.overall,
    required this.categories,
  });

  /// The first day of the month.
  final DateTime month;

  final BudgetItem? overall;

  /// The category budgets, the most used up first.
  final List<BudgetItem> categories;

  bool get isEmpty => overall == null && categories.isEmpty;
}

/// Orders category budgets by how much of the limit is used (most first), then
/// by name. Does not change [items].
List<BudgetItem> sortBudgetItems(Iterable<BudgetItem> items) {
  return items.toList()..sort((a, b) {
    final byPercent = b.progress.percent.compareTo(a.progress.percent);
    if (byPercent != 0) return byPercent;
    final byName = (a.categoryName ?? '').toLowerCase().compareTo(
      (b.categoryName ?? '').toLowerCase(),
    );
    return byName != 0 ? byName : a.id.compareTo(b.id);
  });
}
