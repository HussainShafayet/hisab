import 'dart:math' as math;

import 'package:hishab/core/utils/dates.dart';

/// The icons a goal can have, by the key that is saved.
const goalIcons = [
  'target',
  'laptop',
  'phone',
  'bike',
  'car',
  'home',
  'travel',
  'education',
  'wedding',
  'gift',
  'health',
  'emergency',
];

const defaultGoalIcon = 'target';

/// Something being saved up for.
class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.target,
    required this.icon,
    required this.createdAt,
    this.targetDate,
  });

  final int id;
  final String name;

  /// In poisha, above zero.
  final int target;

  /// The day it should be reached by (local, midnight), if there is one.
  final DateTime? targetDate;

  final String icon;
  final DateTime createdAt;
}

/// Money put into a goal (above zero) or taken out (below zero).
class GoalEntry {
  const GoalEntry({
    required this.id,
    required this.goalId,
    required this.amount,
    required this.date,
    required this.note,
  });

  final int id;
  final int goalId;

  /// In poisha, not zero.
  final int amount;

  /// Local time.
  final DateTime date;
  final String note;

  bool get isTakeOut => amount < 0;
}

int _ceilDiv(int a, int b) => (a + b - 1) ~/ b;

/// A goal with what has been put aside for it, and what follows from that.
class GoalWithSaved {
  const GoalWithSaved({required this.goal, required this.saved});

  final SavingsGoal goal;

  /// In poisha: all that was put in less all that was taken out.
  final int saved;

  /// What is still missing, in poisha; zero once the target is reached.
  int get left => math.max(0, goal.target - saved);

  /// How much of the target is saved, from 0 to 1.
  double get fraction => (saved / goal.target).clamp(0.0, 1.0).toDouble();

  bool get isReached => saved >= goal.target;

  /// Days from [today] to the target day (negative once it has passed), or
  /// null when the goal has no day.
  int? daysLeft(DateTime today) {
    final day = goal.targetDate;
    return day == null ? null : daysBetween(dateOnly(today), dateOnly(day));
  }

  /// The day has passed and the target is not reached.
  bool isLate(DateTime today) {
    final days = daysLeft(today);
    return !isReached && days != null && days < 0;
  }

  /// What to put aside each month (30 days) to reach the target by its day, in
  /// poisha. Null without a day, once reached, or once the day has passed.
  int? perMonth(DateTime today) {
    final days = daysLeft(today);
    if (isReached || days == null || days <= 0) return null;
    return _ceilDiv(left, math.max(1, _ceilDiv(days, 30)));
  }

  /// Like [perMonth], for each week.
  int? perWeek(DateTime today) {
    final days = daysLeft(today);
    if (isReached || days == null || days <= 0) return null;
    return _ceilDiv(left, math.max(1, _ceilDiv(days, 7)));
  }
}

/// All that is put aside across [goals], in poisha.
int totalSaved(Iterable<GoalWithSaved> goals) =>
    goals.fold(0, (sum, g) => sum + g.saved);

/// All the goals want, in poisha.
int totalTarget(Iterable<GoalWithSaved> goals) =>
    goals.fold(0, (sum, g) => sum + g.goal.target);
