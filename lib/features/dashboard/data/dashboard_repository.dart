import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/accounts/data/accounts_repository.dart';
import 'package:hishab/features/budget/data/budgets_repository.dart';
import 'package:hishab/features/dashboard/domain/dashboard_data.dart';
import 'package:hishab/features/reports/data/reports_repository.dart';

/// Gathers what the Home screen shows.
class DashboardRepository {
  DashboardRepository(AppDatabase db)
    : _reports = ReportsRepository(db),
      _accounts = AccountsRepository(db),
      _budgets = BudgetsRepository(db);

  final ReportsRepository _reports;
  final AccountsRepository _accounts;
  final BudgetsRepository _budgets;

  /// The dashboard as of [now]: this month, today, and this week (Sunday to
  /// Saturday).
  Future<DashboardData> load(DateTime now) async {
    final month = monthRange(now);
    final today = dateOnly(now);
    final weekStart = startOfWeek(now);

    DateRange days(DateTime start, int count) => (
      start: start,
      end: DateTime(start.year, start.month, start.day + count),
    );

    final topCategories = await _reports.expenseByCategory(month);
    return DashboardData(
      month: month.start,
      monthTotals: await _reports.totals(month),
      totalBalance: await _accounts.totalBalance(),
      overallBudget: await _budgets.overallBudget(now),
      todayExpense: (await _reports.totals(days(today, 1))).expense,
      weekExpense: (await _reports.totals(days(weekStart, 7))).expense,
      topCategories: topCategories.take(3).toList(),
      recent: await _reports.recentTransactions(),
    );
  }
}
