import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// A few facts about how the money was spent in a period.
class ReportHighlights {
  const ReportHighlights({
    required this.expenseCount,
    required this.averageExpense,
    required this.daysInPeriod,
    required this.noSpendDays,
    required this.byWeekday,
    this.biggestDay,
    this.biggestDayTotal = 0,
  });

  /// How many expenses there were.
  final int expenseCount;

  /// In poisha: the average size of an expense.
  final int averageExpense;

  /// The days of the period so far.
  final int daysInPeriod;

  /// Days of the period so far with no spending at all.
  final int noSpendDays;

  /// Spending on each weekday, Sunday first (index 0), in poisha.
  final List<int> byWeekday;

  /// The day with most spent, and how much.
  final DateTime? biggestDay;
  final int biggestDayTotal;

  /// The weekday (0 is Sunday) with most spent, or null when nothing was.
  int? get busiestWeekday {
    var best = -1;
    var top = 0;
    for (var i = 0; i < byWeekday.length; i++) {
      if (byWeekday[i] > top) {
        top = byWeekday[i];
        best = i;
      }
    }
    return best < 0 ? null : best;
  }
}

/// Works out the [ReportHighlights] of [items], which lie in [range]. The days
/// of a period that is still going are counted up to [now]. Balance fixes and
/// transfers are not spending.
ReportHighlights highlightsOf(
  Iterable<TransactionItem> items, {
  required DateRange range,
  required DateTime now,
}) {
  final spentOn = <DateTime, int>{};
  final byWeekday = List.filled(7, 0);
  var count = 0;
  var total = 0;
  for (final item in items) {
    if (item.isAdjustment || item.type != TransactionType.expense) continue;
    final local = item.date.toLocal();
    final day = dateOnly(local);
    spentOn[day] = (spentOn[day] ?? 0) + item.amount;
    // DateTime.weekday: Monday 1 .. Sunday 7.
    byWeekday[local.weekday % 7] += item.amount;
    count++;
    total += item.amount;
  }

  final lastDay = now.isBefore(range.end)
      ? dateOnly(now)
      : DateTime(range.end.year, range.end.month, range.end.day - 1);
  final days = lastDay.difference(dateOnly(range.start)).inDays + 1;
  final daysSoFar = days < 1 ? 0 : days;
  final spendDays = spentOn.keys
      .where((day) => !day.isBefore(range.start) && !day.isAfter(lastDay))
      .length;

  DateTime? biggestDay;
  var biggest = 0;
  for (final entry in spentOn.entries) {
    if (entry.value > biggest) {
      biggest = entry.value;
      biggestDay = entry.key;
    }
  }

  return ReportHighlights(
    expenseCount: count,
    averageExpense: count == 0 ? 0 : total ~/ count,
    daysInPeriod: daysSoFar,
    noSpendDays: (daysSoFar - spendDays).clamp(0, daysSoFar),
    byWeekday: byWeekday,
    biggestDay: biggestDay,
    biggestDayTotal: biggest,
  );
}
