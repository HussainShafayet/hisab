import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/transactions/domain/feeling_summary.dart';

/// What Takka looks at to hand out badges.
class ActivityFacts {
  const ActivityFacts({
    this.days = const {},
    this.markedExpenses = 0,
    this.lastRegret,
    this.goalReached = false,
    this.loanSettled = false,
    this.hasMetals = false,
  });

  /// Every local day with an entry, and whether an expense was written that
  /// day. Dates are at midnight.
  final Map<DateTime, bool> days;

  /// How many expenses were marked needed, wanted or regret.
  final int markedExpenses;
  final DateTime? lastRegret;
  final bool goalReached;
  final bool loanSettled;
  final bool hasMetals;
}

DateTime _yesterday(DateTime today) =>
    DateTime(today.year, today.month, today.day - 1);

/// How many days in a row, ending today, an entry was written. A day that is
/// not over yet cannot break it: with nothing written today, the run that
/// ended yesterday still counts.
int writingStreak(Iterable<DateTime> days, DateTime today) {
  final set = {for (final d in days) dateOnly(d)};
  var day = dateOnly(today);
  if (!set.contains(day)) day = _yesterday(day);
  var count = 0;
  while (set.contains(day)) {
    count++;
    day = _yesterday(day);
  }
  return count;
}

/// The longest run of days in a row with an entry, ever.
int bestWritingStreak(Iterable<DateTime> days) {
  final sorted = ({for (final d in days) dateOnly(d)}).toList()..sort();
  var best = 0;
  var run = 0;
  DateTime? previous;
  for (final day in sorted) {
    run = previous != null && daysBetween(previous, day) == 1 ? run + 1 : 1;
    if (run > best) best = run;
    previous = day;
  }
  return best;
}

/// How many days with no spending there were, from [from] (or the first day
/// anything was written, if that is later) up to yesterday. Today is not over,
/// so it does not count yet.
int spendFreeDays(Map<DateTime, bool> days, DateTime today, {DateTime? from}) {
  if (days.isEmpty) return 0;
  final first = days.keys.map(dateOnly).reduce((a, b) => a.isBefore(b) ? a : b);
  var start = from == null ? first : dateOnly(from);
  if (start.isBefore(first)) start = first;
  final spent = {
    for (final e in days.entries)
      if (e.value) dateOnly(e.key),
  };
  final last = _yesterday(dateOnly(today));
  var count = 0;
  for (
    var day = start;
    !day.isAfter(last);
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    if (!spent.contains(day)) count++;
  }
  return count;
}

enum BadgeId {
  firstEntry,
  streak3,
  streak7,
  streak30,
  spendFreeDay,
  spendFree10,
  selfAware,
  regretFreeWeek,
  goalReached,
  loanSettled,
  goldKeeper,
}

/// How many marked expenses it takes to be "honest with myself".
const markedForSelfAware = 5;

/// The name of a badge.
String badgeTitle(BadgeId id) => switch (id) {
  BadgeId.firstEntry => tr('First step'),
  BadgeId.streak3 => tr('Three in a row'),
  BadgeId.streak7 => tr('A week of hishab'),
  BadgeId.streak30 => tr('Hishab master'),
  BadgeId.spendFreeDay => tr('Pocket rest'),
  BadgeId.spendFree10 => tr('Saver in the making'),
  BadgeId.selfAware => tr('Honest with myself'),
  BadgeId.regretFreeWeek => tr('Clear mind'),
  BadgeId.goalReached => tr('Dream come true'),
  BadgeId.loanSettled => tr('Clean slate'),
  BadgeId.goldKeeper => tr('Gold keeper'),
};

/// What it takes to get a badge.
String badgeHowTo(BadgeId id) => switch (id) {
  BadgeId.firstEntry => tr('Write your first entry.'),
  BadgeId.streak3 => tr('Write entries 3 days in a row.'),
  BadgeId.streak7 => tr('Write entries 7 days in a row.'),
  BadgeId.streak30 => tr('Write entries 30 days in a row.'),
  BadgeId.spendFreeDay => tr('Have a day with no spending.'),
  BadgeId.spendFree10 => tr('Have 10 days with no spending.'),
  BadgeId.selfAware => tr('Mark 5 expenses as needed, wanted or regret.'),
  BadgeId.regretFreeWeek => tr(
    'Go 7 days without a regret, after marking 5 expenses.',
  ),
  BadgeId.goalReached => tr('Reach a savings goal.'),
  BadgeId.loanSettled => tr('Settle a loan completely.'),
  BadgeId.goldKeeper => tr('Add a piece of gold or silver.'),
};

class BadgeStatus {
  const BadgeStatus(this.id, {required this.earned});

  final BadgeId id;
  final bool earned;
}

/// The streaks and badges for [facts] on [today].
class BadgeReport {
  const BadgeReport({
    required this.streak,
    required this.bestStreak,
    required this.spendFreeThisMonth,
    required this.badges,
  });

  /// The writing streak that is running now.
  final int streak;
  final int bestStreak;

  /// Days with no spending this month, up to yesterday.
  final int spendFreeThisMonth;
  final List<BadgeStatus> badges;

  int get earned => badges.where((b) => b.earned).length;
}

BadgeReport badgeReportOf(ActivityFacts facts, DateTime today) {
  final days = facts.days.keys;
  final streak = writingStreak(days, today);
  final best = bestWritingStreak(days);
  final spendFreeEver = spendFreeDays(facts.days, today);
  final sinceRegret = FeelingSummary(lastRegret: facts.lastRegret)
      .daysSinceRegret(today);

  final earned = {
    BadgeId.firstEntry: facts.days.isNotEmpty,
    BadgeId.streak3: best >= 3,
    BadgeId.streak7: best >= 7,
    BadgeId.streak30: best >= 30,
    BadgeId.spendFreeDay: spendFreeEver >= 1,
    BadgeId.spendFree10: spendFreeEver >= 10,
    BadgeId.selfAware: facts.markedExpenses >= markedForSelfAware,
    BadgeId.regretFreeWeek:
        facts.markedExpenses >= markedForSelfAware &&
        (sinceRegret == null || sinceRegret >= 7),
    BadgeId.goalReached: facts.goalReached,
    BadgeId.loanSettled: facts.loanSettled,
    BadgeId.goldKeeper: facts.hasMetals,
  };
  return BadgeReport(
    streak: streak,
    bestStreak: best,
    spendFreeThisMonth: spendFreeDays(
      facts.days,
      today,
      from: monthStart(today),
    ),
    badges: [
      for (final id in BadgeId.values) BadgeStatus(id, earned: earned[id]!),
    ],
  );
}
