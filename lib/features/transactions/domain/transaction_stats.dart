import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// A few numbers about the transactions being listed, for the line under the
/// summary: how many, what is spent a day, the biggest one and where most went.
/// Balance fixes and transfers are not spending and never count.
class TransactionStats {
  const TransactionStats({
    required this.count,
    required this.expensePerDay,
    this.biggestExpense,
    this.topCategory,
  });

  /// Entries of the person's, balance fixes left out.
  final int count;

  /// In poisha: the expenses divided by the days of the period so far.
  final int expensePerDay;

  final TransactionItem? biggestExpense;

  /// The category with the most spent, and how much (in poisha).
  final ({String name, int total})? topCategory;
}

/// Works out the [TransactionStats] of [items], which lie in [range]. A period
/// that is still going counts its days up to [now]; one that is over, all of
/// them.
TransactionStats statsOf(
  Iterable<TransactionItem> items, {
  required DateRange range,
  required DateTime now,
}) {
  var count = 0;
  var spent = 0;
  TransactionItem? biggest;
  final byCategory = <String, int>{};
  for (final item in items) {
    if (item.isAdjustment) continue;
    count++;
    if (item.type != TransactionType.expense) continue;
    spent += item.amount;
    if (biggest == null || item.amount > biggest.amount) biggest = item;
    final name = item.categoryName;
    if (name != null) byCategory[name] = (byCategory[name] ?? 0) + item.amount;
  }

  final lastDay = now.isBefore(range.end)
      ? dateOnly(now)
      : DateTime(range.end.year, range.end.month, range.end.day - 1);
  final days = lastDay.difference(dateOnly(range.start)).inDays + 1;

  ({String name, int total})? top;
  for (final entry in byCategory.entries) {
    if (top == null || entry.value > top.total) {
      top = (name: entry.key, total: entry.value);
    }
  }
  return TransactionStats(
    count: count,
    expensePerDay: days < 1 ? spent : spent ~/ days,
    biggestExpense: biggest,
    topCategory: top,
  );
}
