import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/categories/data/category_mapper.dart';
import 'package:hishab/features/reports/domain/account_total.dart';
import 'package:hishab/features/reports/domain/category_branch.dart';
import 'package:hishab/features/reports/domain/category_total.dart';
import 'package:hishab/features/reports/domain/period_totals.dart';
import 'package:hishab/features/reports/domain/report_data.dart';
import 'package:hishab/features/transactions/data/transactions_repository.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// Sums over a period for the Reports screen and the Home screen. Income and
/// expense never include transfers or balance adjustments.
class ReportsRepository {
  ReportsRepository(this._db);

  final AppDatabase _db;

  /// How many months the income-versus-expense chart shows.
  static const chartMonths = 6;

  /// How many expenses the "top expenses" list shows.
  static const topExpenseCount = 10;

  Future<PeriodTotals> totals(DateRange range) async {
    final sums = await _db.reportsDao.incomeExpenseTotals(
      range.start,
      range.end,
    );
    return PeriodTotals(income: sums.income, expense: sums.expense);
  }

  /// Expenses by top-level category, biggest first.
  Future<List<CategoryTotal>> expenseByCategory(DateRange range) async {
    final rows = await _db.reportsDao.expenseByCategory(range.start, range.end);
    return [
      for (final row in rows)
        CategoryTotal(
          categoryId: row.categoryId,
          name: row.name,
          icon: row.icon,
          color: row.color,
          total: row.total,
        ),
    ];
  }

  /// Income and expense of the [count] months that end with [endMonth],
  /// oldest first.
  Future<List<CategoryTotal>> incomeByCategory(DateRange range) async {
    final rows = await _db.reportsDao.incomeByCategory(range.start, range.end);
    return [
      for (final row in rows)
        CategoryTotal(
          categoryId: row.categoryId,
          name: row.name,
          icon: row.icon,
          color: row.color,
          total: row.total,
        ),
    ];
  }

  /// The money of [type] in [range] down the category tree.
  Future<List<CategoryBranch>> categoryBranches(
    DateRange range,
    TransactionType type,
  ) async {
    final own = await _db.reportsDao.ownTotalsByCategory(
      type,
      range.start,
      range.end,
    );
    final rows = await _db.categoriesDao.getAll(includeArchived: true);
    return buildBranches([for (final row in rows) row.toDomain()], own);
  }

  /// Income and expense of each account in [range].
  Future<List<AccountTotal>> accountTotals(DateRange range) async {
    final rows = await _db.reportsDao.incomeExpenseByAccount(
      range.start,
      range.end,
    );
    return [
      for (final row in rows)
        AccountTotal(
          accountId: row.accountId,
          name: row.name,
          income: row.income,
          expense: row.expense,
        ),
    ];
  }

  Future<List<MonthTotals>> monthlyTotals(
    DateTime endMonth, {
    int count = chartMonths,
  }) async => [
    for (final month in lastMonths(endMonth, count))
      MonthTotals(month: month, totals: await totals(monthRange(month))),
  ];

  /// The biggest single expenses of [range], biggest first.
  Future<List<TransactionItem>> topExpenses(
    DateRange range, {
    int limit = topExpenseCount,
  }) async {
    final rows = await _db.transactionsDao.topExpensesWithDetails(
      range.start,
      range.end,
      limit: limit,
    );
    return rows.map(toTransactionItem).toList();
  }

  /// The latest transactions of any kind, newest first.
  Future<List<TransactionItem>> recentTransactions({int limit = 5}) async {
    final rows = await _db.transactionsDao.latestWithDetails(limit: limit);
    return rows.map(toTransactionItem).toList();
  }

  /// Everything the Reports screen shows for [range]. The chart ends with the
  /// month that [range] ends in.
  Future<ReportData> loadReport(DateRange range) async {
    final previous = previousPeriod(range);
    final lastDay = DateTime(
      range.end.year,
      range.end.month,
      range.end.day - 1,
    );
    return ReportData(
      range: range,
      totals: await totals(range),
      previousRange: previous,
      previousTotals: await totals(previous),
      categories: await expenseByCategory(range),
      incomeCategories: await incomeByCategory(range),
      accounts: await accountTotals(range),
      expenseBranches: await categoryBranches(range, TransactionType.expense),
      incomeBranches: await categoryBranches(range, TransactionType.income),
      months: await monthlyTotals(lastDay),
      topExpenses: await topExpenses(range),
    );
  }
}
