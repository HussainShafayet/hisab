import 'package:hishab/core/utils/dates.dart';

enum BudgetLevel {
  /// Under 80% of the limit is spent.
  ok,

  /// 80% or more, but under 100%.
  warning,

  /// 100% or more of the limit is spent.
  over,
}

/// How much of a budget [limit] is used up by [spent], both in poisha.
class BudgetProgress {
  const BudgetProgress({required this.limit, required this.spent});

  final int limit;
  final int spent;

  /// What is left. Negative when more than the limit was spent.
  int get remaining => limit - spent;

  /// Whole percent used, rounded down, and above 100 when over the limit.
  /// Rounded down so that "80%" is only shown once 80% is really reached,
  /// exactly when the level turns to [BudgetLevel.warning].
  int get percent => limit <= 0 ? 0 : spent * 100 ~/ limit;

  /// For drawing a bar: 0 to 1.
  double get fraction => limit <= 0 ? 0 : (spent / limit).clamp(0, 1);

  BudgetLevel get level {
    if (percent >= 100) return BudgetLevel.over;
    if (percent >= 80) return BudgetLevel.warning;
    return BudgetLevel.ok;
  }
}

/// Days left in [month] counting [today], or null when [month] is already
/// over. A future month has all its days left.
int? daysLeftInMonth(DateTime month, DateTime today) {
  final thisMonth = monthStart(today);
  final target = monthStart(month);
  if (target.isBefore(thisMonth)) return null;
  if (target.isAfter(thisMonth)) return daysInMonth(target);
  return daysInMonth(target) - today.day + 1;
}

/// What can still be spent each day to stay within the budget: the remaining
/// amount divided by the days left, rounded down to a whole poisha. Zero when
/// nothing is left. Null when [month] is already over.
int? remainingPerDay({
  required int remaining,
  required DateTime month,
  required DateTime today,
}) {
  final days = daysLeftInMonth(month, today);
  if (days == null) return null;
  return remaining <= 0 ? 0 : remaining ~/ days;
}
