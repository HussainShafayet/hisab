import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// Something spent on again and again.
class Habit {
  const Habit({
    required this.categoryId,
    required this.name,
    required this.count,
    required this.total,
    required this.perMonth,
  });

  final int categoryId;
  final String name;

  /// How many times in the period.
  final int count;

  /// In poisha: all of it.
  final int total;

  /// In poisha: what that comes to in a month of 30 days.
  final int perMonth;
}

/// How many days back a habit is looked for.
const habitWindowDays = 30;

/// A category is a habit from this many expenses in the window.
const habitMinCount = 8;

/// The categories spent on again and again in the last [habitWindowDays] days
/// before [today]: at least [habitMinCount] expenses, the one that cost most
/// first. Balance fixes and transfers are not spending, and an expense with no
/// category has no name to call a habit.
List<Habit> habitsOf(
  Iterable<TransactionItem> items, {
  required DateTime today,
  int take = 3,
}) {
  final from = dateOnly(today)
      .subtract(const Duration(days: habitWindowDays - 1));
  final end = dateOnly(today).add(const Duration(days: 1));
  final counts = <int, int>{};
  final totals = <int, int>{};
  final names = <int, String>{};
  for (final item in items) {
    if (item.isAdjustment || item.type != TransactionType.expense) continue;
    final id = item.categoryId;
    final name = item.categoryName;
    if (id == null || name == null) continue;
    final day = dateOnly(item.date.toLocal());
    if (day.isBefore(from) || !day.isBefore(end)) continue;
    counts[id] = (counts[id] ?? 0) + 1;
    totals[id] = (totals[id] ?? 0) + item.amount;
    names[id] = name;
  }
  final habits = [
    for (final entry in counts.entries)
      if (entry.value >= habitMinCount)
        Habit(
          categoryId: entry.key,
          name: names[entry.key]!,
          count: entry.value,
          total: totals[entry.key]!,
          perMonth: totals[entry.key]! * 30 ~/ habitWindowDays,
        ),
  ]..sort((a, b) => b.total.compareTo(a.total));
  return habits.take(take).toList();
}
