import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/investments/domain/investment.dart';

/// How long an investment has been going and how fast it pays back.
class InvestmentFacts {
  const InvestmentFacts({
    required this.heldDays,
    required this.recoveredPercent,
    this.annualPercent,
    this.profitPerMonth,
    this.paybackMonths,
  });

  /// Days since it started (until it was closed, if it was).
  final int heldDays;

  /// How much of the money put in has come back (profit and money taken back),
  /// as a whole percent. It can go above 100.
  final int recoveredPercent;

  /// The return as a percent of a year, worked out from the days held. Null
  /// before 30 days (too soon to say) or when nothing was put in.
  final int? annualPercent;

  /// In poisha: the profit received divided by the months held. Null with no
  /// profit yet or before 30 days.
  final int? profitPerMonth;

  /// About how many more months of profit at that pace it takes to get all the
  /// money back. Null when it is already back, or there is no pace.
  final int? paybackMonths;
}

/// Works out the [InvestmentFacts] of [item] as of [today]. [lastLine] is the
/// day of its last line, which ends a closed investment.
InvestmentFacts factsOf(
  InvestmentItem item, {
  required DateTime today,
  DateTime? lastLine,
}) {
  final started = dateOnly(item.investment.startedOn);
  final end = item.investment.isClosed && lastLine != null
      ? dateOnly(lastLine)
      : dateOnly(today);
  final days = end.difference(started).inDays;
  final held = days < 0 ? 0 : days;

  final recovered = item.putIn <= 0
      ? 0
      : (item.profit + item.takenBack) * 100 ~/ item.putIn;

  int? annual;
  if (item.putIn > 0 && held >= 30) {
    annual = item.totalReturn * 100 * 365 ~/ (item.putIn * held);
  }

  int? perMonth;
  if (item.profit > 0 && held >= 30) {
    perMonth = item.profit * 30 ~/ held;
  }

  final unrecovered = item.putIn - item.profit - item.takenBack;
  int? payback;
  if (perMonth != null && perMonth > 0 && unrecovered > 0) {
    payback = (unrecovered + perMonth - 1) ~/ perMonth;
  }

  return InvestmentFacts(
    heldDays: held,
    recoveredPercent: recovered,
    annualPercent: annual,
    profitPerMonth: perMonth,
    paybackMonths: payback,
  );
}

/// The profit received in one month.
class MonthProfit {
  const MonthProfit({required this.month, required this.amount});

  /// The first day of the month.
  final DateTime month;
  final int amount;
}

/// The profit received in each of the last [months] months up to [today],
/// oldest first. Months with none are there with zero.
List<MonthProfit> profitByMonth(
  Iterable<InvestmentEntry> entries, {
  required DateTime today,
  int months = 12,
}) {
  final first = addMonths(monthStart(today), -(months - 1));
  final totals = <DateTime, int>{};
  for (final entry in entries) {
    if (entry.kind != InvestmentEntryKind.profit) continue;
    final month = monthStart(entry.date.toLocal());
    totals[month] = (totals[month] ?? 0) + entry.amount;
  }
  return [
    for (var i = 0; i < months; i++)
      MonthProfit(
        month: addMonths(first, i),
        amount: totals[addMonths(first, i)] ?? 0,
      ),
  ];
}

/// How the investments in the list can be ordered.
enum InvestmentSort { newest, bestReturn, mostPutIn }

/// Which investments the list shows.
enum InvestmentFilter { all, open, closed }

/// [items] narrowed by [filter] and put in the order of [sort]. Ties keep the
/// newest first.
List<InvestmentItem> arrangeInvestments(
  Iterable<InvestmentItem> items, {
  required InvestmentFilter filter,
  required InvestmentSort sort,
}) {
  final shown = [
    for (final item in items)
      if (filter == InvestmentFilter.all ||
          (filter == InvestmentFilter.open) != item.investment.isClosed)
        item,
  ];
  int newest(InvestmentItem a, InvestmentItem b) =>
      b.investment.id.compareTo(a.investment.id);
  shown.sort((a, b) {
    final by = switch (sort) {
      InvestmentSort.newest => 0,
      InvestmentSort.bestReturn => b.totalReturn.compareTo(a.totalReturn),
      InvestmentSort.mostPutIn => b.putIn.compareTo(a.putIn),
    };
    return by != 0 ? by : newest(a, b);
  });
  return shown;
}
