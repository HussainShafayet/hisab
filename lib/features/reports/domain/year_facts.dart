import 'package:hishab/features/reports/domain/period_totals.dart';

/// What a year of months says: the averages and the best and worst months.
class YearFacts {
  const YearFacts({
    required this.activeMonths,
    required this.averageIncome,
    required this.averageExpense,
    this.mostSpent,
    this.mostKept,
  });

  /// How many months have any income or expense (and are not in the future).
  final int activeMonths;

  /// Per month with entries, in poisha.
  final int averageIncome;
  final int averageExpense;

  /// The month with the most expense, or null when nothing was spent.
  final MonthTotals? mostSpent;

  /// The month with the most left over (income minus expense), or null when no
  /// month ended above zero.
  final MonthTotals? mostKept;
}

/// The facts of [months] (a year, or part of one). A month that starts after
/// [now] is left out, and so is one with no income and no expense: a year in
/// which the person only began in October is averaged over the months they
/// wrote down, not over twelve.
YearFacts yearFacts(List<MonthTotals> months, {required DateTime now}) {
  final active = [
    for (final month in months)
      if (!month.month.isAfter(now) &&
          (month.totals.income > 0 || month.totals.expense > 0))
        month,
  ];
  if (active.isEmpty) {
    return const YearFacts(
      activeMonths: 0,
      averageIncome: 0,
      averageExpense: 0,
    );
  }

  var income = 0;
  var expense = 0;
  MonthTotals? mostSpent;
  MonthTotals? mostKept;
  for (final month in active) {
    income += month.totals.income;
    expense += month.totals.expense;
    if (month.totals.expense > 0 &&
        (mostSpent == null ||
            month.totals.expense > mostSpent.totals.expense)) {
      mostSpent = month;
    }
    if (month.totals.net > 0 &&
        (mostKept == null || month.totals.net > mostKept.totals.net)) {
      mostKept = month;
    }
  }
  return YearFacts(
    activeMonths: active.length,
    averageIncome: income ~/ active.length,
    averageExpense: expense ~/ active.length,
    mostSpent: mostSpent,
    mostKept: mostKept,
  );
}
