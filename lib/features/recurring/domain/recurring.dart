import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// How often a recurring transaction comes round.
enum RecurrenceFrequency { weekly, monthly, yearly }

/// An income or expense that repeats, like rent or a salary.
class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.title,
    required this.type,
    required this.amount,
    required this.accountId,
    required this.categoryId,
    required this.frequency,
    required this.startDate,
    required this.nextDue,
    required this.autoAdd,
    required this.remind,
    required this.isPaused,
    this.endDate,
  });

  final int id;

  /// What it is called, and the note of the transactions it makes.
  final String title;

  /// Income or expense, never a transfer.
  final TransactionType type;

  /// In poisha, above zero.
  final int amount;
  final int accountId;
  final int categoryId;
  final RecurrenceFrequency frequency;

  /// The first day it is due. A monthly rule keeps this day of the month.
  final DateTime startDate;

  /// The next day that has not been added or skipped yet.
  final DateTime nextDue;

  /// The last day it can be due, if it ends.
  final DateTime? endDate;

  /// Adds the transaction by itself when it is due, instead of asking.
  final bool autoAdd;

  /// Shows a notification on the day, when it is not added by itself.
  final bool remind;
  final bool isPaused;

  /// No more days are left: the next one would be after [endDate].
  bool get isFinished => endDate != null && nextDue.isAfter(endDate!);

  /// Still making days: not paused and not finished.
  bool get isActive => !isPaused && !isFinished;
}

/// The day after [date] for a rule that started on [anchor].
///
/// Weekly is seven days later. Monthly keeps the day of the month of [anchor]
/// and uses the last day of a shorter month (the 31st becomes the 30th, or
/// the 28th), then goes back to the 31st. Yearly keeps the month and day.
DateTime nextOccurrence(
  DateTime date,
  RecurrenceFrequency frequency,
  DateTime anchor,
) {
  switch (frequency) {
    case RecurrenceFrequency.weekly:
      return DateTime(date.year, date.month, date.day + 7);
    case RecurrenceFrequency.monthly:
      final month = DateTime(date.year, date.month + 1);
      final last = daysInMonth(month);
      return DateTime(
        month.year,
        month.month,
        anchor.day > last ? last : anchor.day,
      );
    case RecurrenceFrequency.yearly:
      final month = DateTime(date.year + 1, anchor.month);
      final last = daysInMonth(month);
      return DateTime(
        month.year,
        month.month,
        anchor.day > last ? last : anchor.day,
      );
  }
}

/// The days of [rule] that are due: from [RecurringRule.nextDue] up to and
/// including [today], and not after its end. At most [limit], oldest first.
List<DateTime> dueDates(RecurringRule rule, DateTime today, {int limit = 60}) {
  final last = dateOnly(today);
  final dates = <DateTime>[];
  var day = rule.nextDue;
  while (!day.isAfter(last) && dates.length < limit) {
    if (rule.endDate != null && day.isAfter(rule.endDate!)) break;
    dates.add(day);
    day = nextOccurrence(day, rule.frequency, rule.startDate);
  }
  return dates;
}

/// A rule that is waiting to be added or skipped.
class DueItem {
  const DueItem({required this.rule, required this.due, required this.more});

  final RecurringRule rule;

  /// The day waiting now: the oldest one that is due.
  final DateTime due;

  /// How many later days are due too (missed while the app was closed).
  final int more;
}

/// The rules that have a day waiting on or before [today], oldest first. A
/// paused rule has none.
List<DueItem> dueItemsOf(Iterable<RecurringRule> rules, DateTime today) {
  final items = <DueItem>[];
  for (final rule in rules) {
    if (rule.isPaused) continue;
    final dates = dueDates(rule, today);
    if (dates.isEmpty) continue;
    items.add(DueItem(rule: rule, due: dates.first, more: dates.length - 1));
  }
  items.sort((a, b) {
    final byDue = a.due.compareTo(b.due);
    return byDue != 0 ? byDue : a.rule.id.compareTo(b.rule.id);
  });
  return items;
}

/// A notification to show for a rule on a day.
class PlannedReminder {
  const PlannedReminder({
    required this.rule,
    required this.day,
    required this.index,
  });

  final RecurringRule rule;
  final DateTime day;

  /// 0 for the next day of the rule, 1 for the one after, and so on.
  final int index;
}

/// The days to remind about: for each active rule that asks for reminders and
/// does not add itself, its next [perRule] days that are today or later, in
/// order, and at most [maxTotal] in all (the phone limits how many can be
/// scheduled).
List<PlannedReminder> upcomingReminders(
  Iterable<RecurringRule> rules,
  DateTime today, {
  int perRule = 3,
  int maxTotal = 40,
}) {
  final from = dateOnly(today);
  final planned = <PlannedReminder>[];
  for (final rule in rules) {
    if (!rule.isActive || !rule.remind || rule.autoAdd) continue;
    var day = rule.nextDue;
    // Days already past are in the "due" list, not reminders.
    while (day.isBefore(from)) {
      day = nextOccurrence(day, rule.frequency, rule.startDate);
    }
    for (var index = 0; index < perRule; index++) {
      if (rule.endDate != null && day.isAfter(rule.endDate!)) break;
      planned.add(PlannedReminder(rule: rule, day: day, index: index));
      day = nextOccurrence(day, rule.frequency, rule.startDate);
    }
  }
  planned.sort((a, b) {
    final byDay = a.day.compareTo(b.day);
    return byDay != 0 ? byDay : a.rule.id.compareTo(b.rule.id);
  });
  return planned.take(maxTotal).toList();
}
