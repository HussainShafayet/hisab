import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/reports/domain/category_total.dart';

/// What an insight is about. The text for each is in `insight_text.dart`.
enum InsightKind {
  spendingUp,
  spendingDown,
  overBudgetPace,
  withinBudgetPace,
  categoryJump,
  topCategory,
  recurringSoon,
  noSpendDays,
  busyWeekday,
  biggestExpense,
  savingsKept,
  spentMoreThanEarned,
  smallSpends,
  regretShare,
  loanToGet,
  loanToPay,
}

/// Where a tap on an insight goes.
enum InsightLink { report, budget, loans, recurring, transaction }

/// How an insight should feel: something to look at, good news, or a plain
/// fact.
enum InsightTone { warning, good, info }

/// One short observation about the person's money, with the numbers it needs
/// (amounts in poisha, percents and days as they are).
class Insight {
  const Insight(
    this.kind,
    this.tone, [
    this.args = const {},
    this.link,
    this.targetId,
  ]);

  final InsightKind kind;
  final InsightTone tone;
  final Map<String, Object> args;

  /// Where a tap goes, when it goes anywhere.
  final InsightLink? link;

  /// The id the link needs (the transaction to open).
  final int? targetId;
}

/// The biggest single expense of the month.
class BiggestExpense {
  const BiggestExpense({
    required this.id,
    required this.amount,
    required this.label,
  });

  final int id;
  final int amount;

  /// What it was for: the category, or the note.
  final String label;
}

/// A loan that falls due soon.
class UpcomingLoan {
  const UpcomingLoan({
    required this.person,
    required this.amount,
    required this.days,
    required this.lent,
  });

  final String person;

  /// What is left, in poisha.
  final int amount;
  final int days;

  /// Money I lent, which I will get (else money I borrowed and will give).
  final bool lent;
}

/// A recurring item coming up soon.
class UpcomingRecurring {
  const UpcomingRecurring({required this.title, required this.days});

  final String title;

  /// Days from today: 0 for today.
  final int days;
}

/// What the insights are worked out from.
class InsightInput {
  const InsightInput({
    required this.today,
    required this.expense,
    required this.expenseLastPeriod,
    required this.categories,
    required this.categoriesLastPeriod,
    this.budgetLimit,
    this.budgetSpent = 0,
    this.recurring,
    this.income = 0,
    this.noSpendDays = 0,
    this.daysSoFar = 0,
    this.weekdaySpend = const [],
    this.biggestExpense,
    this.smallSpendCount = 0,
    this.smallSpendTotal = 0,
    this.regretTotal = 0,
    this.loan,
  });

  final DateTime today;

  /// Earned this month so far.
  final int income;

  /// Days of the month so far, and how many had no spending.
  final int daysSoFar;
  final int noSpendDays;

  /// Spent on each weekday this month, Sunday first (index 0).
  final List<int> weekdaySpend;

  final BiggestExpense? biggestExpense;

  /// Expenses under [smallSpendLimit] this month: how many, and their total.
  final int smallSpendCount;
  final int smallSpendTotal;

  /// Spent on things marked Regret this month.
  final int regretTotal;

  /// The next loan to fall due, if any.
  final UpcomingLoan? loan;

  /// Spent this month so far.
  final int expense;

  /// Spent in the same days of last month (day 1 to today's day number).
  final int expenseLastPeriod;

  /// This month so far and the same days of last month, by top-level
  /// category.
  final List<CategoryTotal> categories;
  final List<CategoryTotal> categoriesLastPeriod;

  /// The overall budget of this month and what is spent against it.
  final int? budgetLimit;
  final int budgetSpent;

  /// The next recurring item coming up, if any.
  final UpcomingRecurring? recurring;
}

/// The smallest change in spending worth mentioning, in percent.
const spendingChangeThreshold = 10;

/// A category has to be at least this share of the spending to be called out.
const topCategoryShare = 35;

/// A category has to cost at least this much more (poisha, ৳500) and a
/// quarter more than before to be called out as a jump.
const categoryJumpMinimum = 50000;

/// Budget pace is only worked out from this day of the month on, because the
/// first days say little.
const paceFromDay = 3;

/// Recurring items coming up within this many days are mentioned.
const recurringSoonDays = 7;

/// An expense under this (poisha, ৳100) is a small one.
const smallSpendLimit = 10000;

/// Small expenses are mentioned from this many, adding up to at least ৳500.
const smallSpendCountMin = 8;
const smallSpendTotalMin = 50000;

/// Weekday and no-spend facts are only worked out from this day of the month.
const patternFromDay = 7;

/// A loan falling due within this many days is mentioned.
const loanSoonDays = 7;

/// Up to [max] insights, warnings first, then good news, then facts.
List<Insight> buildInsights(InsightInput input, {int max = 4}) {
  final found = <Insight>[];

  // Spending against the same days of last month.
  if (input.expense > 0 && input.expenseLastPeriod > 0) {
    final change =
        (input.expense - input.expenseLastPeriod) *
        100 ~/
        input.expenseLastPeriod;
    if (change >= spendingChangeThreshold) {
      found.add(
        Insight(InsightKind.spendingUp, InsightTone.warning, {
          'percent': change,
        }, InsightLink.report),
      );
    } else if (change <= -spendingChangeThreshold) {
      found.add(
        Insight(InsightKind.spendingDown, InsightTone.good, {
          'percent': -change,
        }, InsightLink.report),
      );
    }
  }

  // The pace of the overall budget.
  final limit = input.budgetLimit;
  if (limit != null &&
      limit > 0 &&
      input.budgetSpent > 0 &&
      input.today.day >= paceFromDay) {
    final projected =
        input.budgetSpent * daysInMonth(input.today) ~/ input.today.day;
    found.add(
      projected > limit
          ? Insight(InsightKind.overBudgetPace, InsightTone.warning, {
              'projected': projected,
              'limit': limit,
            }, InsightLink.budget)
          : Insight(InsightKind.withinBudgetPace, InsightTone.good, {
              'projected': projected,
              'limit': limit,
            }, InsightLink.budget),
    );
  }

  // The category that grew most.
  final before = {
    for (final c in input.categoriesLastPeriod) c.categoryId: c.total,
  };
  CategoryTotal? jump;
  var jumpBy = 0;
  for (final category in input.categories) {
    final was = before[category.categoryId] ?? 0;
    final increase = category.total - was;
    if (was > 0 &&
        increase >= categoryJumpMinimum &&
        increase * 100 ~/ was >= 25 &&
        increase > jumpBy) {
      jump = category;
      jumpBy = increase;
    }
  }
  if (jump != null) {
    found.add(
      Insight(InsightKind.categoryJump, InsightTone.warning, {
        'name': jump.name,
        'amount': jumpBy,
      }, InsightLink.report),
    );
  }

  // The biggest slice of the spending.
  if (input.expense > 0 && input.categories.isNotEmpty) {
    final top = input.categories.first;
    final share = top.total * 100 ~/ input.expense;
    if (share >= topCategoryShare) {
      found.add(
        Insight(InsightKind.topCategory, InsightTone.info, {
          'name': top.name,
          'percent': share,
        }, InsightLink.report),
      );
    }
  }

  final recurring = input.recurring;
  if (recurring != null &&
      recurring.days >= 0 &&
      recurring.days <= recurringSoonDays) {
    found.add(
      Insight(InsightKind.recurringSoon, InsightTone.info, {
        'title': recurring.title,
        'days': recurring.days,
      }, InsightLink.recurring),
    );
  }

  // Days with no spending at all.
  if (input.daysSoFar >= 5 && input.noSpendDays >= 3) {
    found.add(
      Insight(InsightKind.noSpendDays, InsightTone.good, {
        'count': input.noSpendDays,
      }, InsightLink.report),
    );
  }

  // The weekday that takes most.
  if (input.daysSoFar >= 14 &&
      input.expense >= 200000 &&
      input.weekdaySpend.length == 7) {
    var best = 0;
    for (var i = 1; i < 7; i++) {
      if (input.weekdaySpend[i] > input.weekdaySpend[best]) best = i;
    }
    final share = input.weekdaySpend[best] * 100 ~/ input.expense;
    if (share >= 30) {
      found.add(
        Insight(InsightKind.busyWeekday, InsightTone.info, {
          'weekday': best,
          'percent': share,
        }, InsightLink.report),
      );
    }
  }

  // The biggest single expense, when it is a big part of the month.
  final biggest = input.biggestExpense;
  if (biggest != null &&
      input.expense > 0 &&
      biggest.amount >= 100000 &&
      biggest.amount * 100 ~/ input.expense >= 20) {
    found.add(
      Insight(
        InsightKind.biggestExpense,
        InsightTone.info,
        {'amount': biggest.amount, 'label': biggest.label},
        InsightLink.transaction,
        biggest.id,
      ),
    );
  }

  // How much of the income was kept, or overspent.
  if (input.income > 0 && input.today.day >= patternFromDay) {
    final kept = input.income - input.expense;
    if (kept < 0) {
      found.add(
        Insight(InsightKind.spentMoreThanEarned, InsightTone.warning, {
          'amount': -kept,
        }, InsightLink.report),
      );
    } else if (kept * 100 ~/ input.income >= 20) {
      found.add(
        Insight(InsightKind.savingsKept, InsightTone.good, {
          'percent': kept * 100 ~/ input.income,
        }, InsightLink.report),
      );
    }
  }

  // Many small spends that add up.
  if (input.smallSpendCount >= smallSpendCountMin &&
      input.smallSpendTotal >= smallSpendTotalMin) {
    found.add(
      Insight(InsightKind.smallSpends, InsightTone.info, {
        'count': input.smallSpendCount,
        'amount': input.smallSpendTotal,
      }, InsightLink.report),
    );
  }

  // Spending that was marked Regret.
  if (input.expense > 0 && input.regretTotal > 0) {
    final share = input.regretTotal * 100 ~/ input.expense;
    if (share >= 15) {
      found.add(
        Insight(InsightKind.regretShare, InsightTone.warning, {
          'percent': share,
        }, InsightLink.report),
      );
    }
  }

  // A loan about to fall due.
  final loan = input.loan;
  if (loan != null && loan.days >= 0 && loan.days <= loanSoonDays) {
    found.add(
      Insight(
        loan.lent ? InsightKind.loanToGet : InsightKind.loanToPay,
        InsightTone.info,
        {'person': loan.person, 'amount': loan.amount, 'days': loan.days},
        InsightLink.loans,
      ),
    );
  }

  // Warnings, then good news, then facts; each group keeps the order above.
  int rank(Insight insight) => switch (insight.tone) {
    InsightTone.warning => 0,
    InsightTone.good => 1,
    InsightTone.info => 2,
  };
  final indexed =
      [for (var i = 0; i < found.length; i++) (i: i, insight: found[i])]
        ..sort((a, b) {
          final byRank = rank(a.insight).compareTo(rank(b.insight));
          return byRank != 0 ? byRank : a.i.compareTo(b.i);
        });
  return [for (final entry in indexed.take(max)) entry.insight];
}
