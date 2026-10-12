/// Income and expense of a period, in poisha. Transfers and balance
/// adjustments are not part of either.
class PeriodTotals {
  const PeriodTotals({this.income = 0, this.expense = 0});

  final int income;
  final int expense;

  /// Income minus expense. Negative when more was spent than earned.
  int get net => income - expense;
}

/// The totals of one calendar month.
class MonthTotals {
  const MonthTotals({required this.month, required this.totals});

  /// The first day of the month.
  final DateTime month;
  final PeriodTotals totals;
}
