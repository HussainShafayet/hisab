import 'dart:math' as math;

import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/recurring/domain/recurring.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// How much can be spent today without breaking this month's budget: what is
/// left of the budget, less the bills still to come, spread over the days that
/// are left.
class SafeToSpend {
  const SafeToSpend({
    required this.budget,
    required this.spentBeforeToday,
    required this.spentToday,
    required this.upcomingBills,
    required this.daysLeft,
  });

  /// The overall budget of the month, in poisha.
  final int budget;

  /// Spent this month before today, in poisha.
  final int spentBeforeToday;

  /// Spent today, in poisha.
  final int spentToday;

  /// Recurring expenses still to come this month (today included), in poisha.
  final int upcomingBills;

  /// Days from today to the end of the month, today included. At least 1.
  final int daysLeft;

  /// What is left for today and the days after it. Zero or less when the
  /// budget is already used up.
  int get remaining => budget - spentBeforeToday - upcomingBills;

  /// The budget is gone, counting the bills still to come.
  bool get isUsedUp => remaining <= 0;

  /// The same amount for each of the days that are left, in poisha.
  int get perDay => isUsedUp ? 0 : remaining ~/ daysLeft;

  /// What can still be spent today. Below zero when today's share is spent.
  int get leftToday => perDay - spentToday;

  bool get isOverToday => !isUsedUp && leftToday < 0;

  /// How much of today's share is spent, from 0 to 1.
  double get usedToday =>
      perDay <= 0 ? 1.0 : (spentToday / perDay).clamp(0.0, 1.0).toDouble();
}

/// What the active recurring expenses in [rules] will still cost from [today]
/// to the end of its month, in poisha. A day that is due and not yet added
/// counts; one that was added already does not (the rule has moved on).
int upcomingBillsThisMonth(Iterable<RecurringRule> rules, DateTime today) {
  final last = DateTime(today.year, today.month, daysInMonth(today));
  var total = 0;
  for (final rule in rules) {
    if (!rule.isActive || rule.type != TransactionType.expense) continue;
    var day = rule.nextDue;
    while (!day.isAfter(last)) {
      if (rule.endDate != null && day.isAfter(rule.endDate!)) break;
      total += rule.amount;
      day = nextOccurrence(day, rule.frequency, rule.startDate);
    }
  }
  return total;
}

/// The figures for today, or null when the month has no overall budget.
/// [spentThisMonth] includes [spentToday].
SafeToSpend? safeToSpendOf({
  required int? budget,
  required int spentThisMonth,
  required int spentToday,
  required Iterable<RecurringRule> rules,
  required DateTime today,
}) {
  if (budget == null || budget <= 0) return null;
  final day = dateOnly(today);
  return SafeToSpend(
    budget: budget,
    spentBeforeToday: math.max(0, spentThisMonth - spentToday),
    spentToday: spentToday,
    upcomingBills: upcomingBillsThisMonth(rules, day),
    daysLeft: daysInMonth(day) - day.day + 1,
  );
}
