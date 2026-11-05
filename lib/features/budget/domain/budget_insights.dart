import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/budget/domain/budget_item.dart';
import 'package:hishab/features/budget/domain/budget_placement.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// What the month would come to if spending went on at the pace so far, in
/// poisha. Null before the month starts and in its first days, when one big
/// bill would make a guess meaningless; the real total once the month is over.
int? projectedSpend({
  required int spent,
  required DateTime month,
  required DateTime today,
}) {
  final start = monthStart(month);
  final end = addMonths(start, 1);
  if (!today.isBefore(end)) return spent;
  if (today.isBefore(start)) return null;
  final elapsed = dateOnly(today).difference(start).inDays + 1;
  if (elapsed < 3) return null;
  final totalDays = end.difference(start).inDays;
  return (spent * totalDays / elapsed).round();
}

/// How much of the monthly budget the category budgets plan for.
class BudgetAllocation {
  const BudgetAllocation({required this.limit, required this.planned});

  /// The overall monthly limit, in poisha.
  final int limit;

  /// The category budgets added up, in poisha. A budget inside another budget
  /// is part of it and is not counted twice.
  final int planned;

  int get unplanned => limit - planned;

  /// The categories ask for more than the month has.
  bool get over => planned > limit;
}

/// The [BudgetAllocation] of the month: [limit] against the category budgets
/// in [items], counting only the outermost ones ([placements] says which are
/// inside another).
BudgetAllocation allocationOf({
  required int limit,
  required Iterable<BudgetItem> items,
  required Map<int, BudgetPlacement> placements,
}) {
  var planned = 0;
  for (final item in items) {
    final id = item.categoryId;
    if (id == null) continue;
    if (placements[id]?.countedInId != null) continue;
    planned += item.limit;
  }
  return BudgetAllocation(limit: limit, planned: planned);
}

/// Spending in a group of categories that has no budget.
class UnbudgetedGroup {
  const UnbudgetedGroup({
    required this.categoryId,
    required this.name,
    required this.total,
  });

  /// The top-level category, or null for spending with no category.
  final int? categoryId;
  final String name;
  final int total;
}

/// The month's spending that no category budget covers.
class UnbudgetedSpending {
  const UnbudgetedSpending({required this.total, required this.top});

  final int total;

  /// The groups with most spent, biggest first.
  final List<UnbudgetedGroup> top;
}

/// The expenses in [items] whose category is not in [covered] (the budgeted
/// categories and everything inside them), grouped by top-level category. Balance
/// fixes and transfers are not spending. [noCategoryName] names the group of
/// expenses with no category.
UnbudgetedSpending unbudgetedSpending(
  Iterable<TransactionItem> items, {
  required Set<int> covered,
  required Map<int, Category> byId,
  required String noCategoryName,
  int take = 3,
}) {
  var total = 0;
  final groups = <int?, int>{};
  for (final item in items) {
    if (item.isAdjustment || item.type != TransactionType.expense) continue;
    final id = item.categoryId;
    if (id != null && covered.contains(id)) continue;
    total += item.amount;
    final root = id == null ? null : _rootId(id, byId);
    groups[root] = (groups[root] ?? 0) + item.amount;
  }
  final sorted = groups.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return UnbudgetedSpending(
    total: total,
    top: [
      for (final entry in sorted.take(take))
        UnbudgetedGroup(
          categoryId: entry.key,
          name: entry.key == null
              ? noCategoryName
              : (byId[entry.key]?.name ?? noCategoryName),
          total: entry.value,
        ),
    ],
  );
}

int _rootId(int id, Map<int, Category> byId) {
  var current = id;
  final seen = <int>{};
  while (seen.add(current)) {
    final parent = byId[current]?.parentId;
    if (parent == null || byId[parent] == null) break;
    current = parent;
  }
  return current;
}
