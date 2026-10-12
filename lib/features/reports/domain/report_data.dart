import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/reports/domain/category_total.dart';
import 'package:hishab/features/reports/domain/period_totals.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';

/// Everything the Reports screen shows for one period.
class ReportData {
  const ReportData({
    required this.range,
    required this.totals,
    required this.previousRange,
    required this.previousTotals,
    required this.categories,
    required this.months,
    required this.topExpenses,
  });

  final DateRange range;
  final PeriodTotals totals;

  /// The period before [range], to compare with.
  final DateRange previousRange;
  final PeriodTotals previousTotals;

  /// Expenses by top-level category, biggest first.
  final List<CategoryTotal> categories;

  /// Income and expense of the last months, oldest first.
  final List<MonthTotals> months;

  /// The biggest single expenses of the period, biggest first.
  final List<TransactionItem> topExpenses;
}
