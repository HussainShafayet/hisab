import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/reports/domain/category_total.dart';

/// What an insight is about. The text for each is in `insight_text.dart`.
enum InsightKind {
  spendingUp,
  spendingDown,
  overBudgetPace,
  withinBudgetPace,
  categoryJump,
  topCategory,
  loansOverdue,
  loansToGet,
  loansToPay,
  recurringSoon,
}

/// How an insight should feel: something to look at, good news, or a plain
/// fact.
enum InsightTone { warning, good, info }

/// One short observation about the person's money, with the numbers it needs
/// (amounts in poisha, percents and days as they are).
class Insight {
  const Insight(this.kind, this.tone, [this.args = const {}]);

  final InsightKind kind;
  final InsightTone tone;
  final Map<String, Object> args;
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
    this.loans = const DebtTotals(),
    this.recurring,
  });

  final DateTime today;

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
  final DebtTotals loans;

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
        }),
      );
    } else if (change <= -spendingChangeThreshold) {
      found.add(
        Insight(InsightKind.spendingDown, InsightTone.good, {
          'percent': -change,
        }),
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
            })
          : Insight(InsightKind.withinBudgetPace, InsightTone.good, {
              'projected': projected,
              'limit': limit,
            }),
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
      }),
    );
  }

  // Loans.
  if (input.loans.overdueCount > 0) {
    found.add(
      Insight(InsightKind.loansOverdue, InsightTone.warning, {
        'count': input.loans.overdueCount,
      }),
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
        }),
      );
    }
  }

  if (input.loans.toReceive > 0) {
    found.add(
      Insight(InsightKind.loansToGet, InsightTone.info, {
        'amount': input.loans.toReceive,
      }),
    );
  }
  if (input.loans.toPay > 0) {
    found.add(
      Insight(InsightKind.loansToPay, InsightTone.info, {
        'amount': input.loans.toPay,
      }),
    );
  }

  final recurring = input.recurring;
  if (recurring != null &&
      recurring.days >= 0 &&
      recurring.days <= recurringSoonDays) {
    found.add(
      Insight(InsightKind.recurringSoon, InsightTone.info, {
        'title': recurring.title,
        'days': recurring.days,
      }),
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
