import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/fun/domain/badges.dart';
import 'package:hishab/features/fun/domain/wrapped.dart';
import 'package:hishab/features/reports/data/reports_repository.dart';
import 'package:hishab/features/transactions/data/activity_queries.dart';
import 'package:hishab/features/transactions/data/feeling_queries.dart';
import 'package:hishab/features/transactions/domain/feeling_summary.dart';

/// Works out the wrapped of a month from the entries.
class WrappedRepository {
  WrappedRepository(this._db);

  final AppDatabase _db;

  /// The wrapped of [month] (any day in it). [today] decides how far the
  /// spend-free days are counted: not past yesterday.
  Future<MonthWrapped> load(DateTime month, DateTime today) async {
    final range = monthRange(month);
    final reports = ReportsRepository(_db);
    final totals = await reports.totals(range);
    final categories = await reports.expenseByCategory(range);
    final biggest = await reports.topExpenses(range, limit: 1);
    final days = await _db.activityDays();
    final end = dateOnly(today).isBefore(range.end)
        ? dateOnly(today)
        : range.end;
    return MonthWrapped(
      month: range.start,
      income: totals.income,
      expense: totals.expense,
      entries: await _db.entryCount(range.start, range.end),
      spendFreeDays: spendFreeDays(days, end, from: range.start),
      feelings: FeelingSummary.of(
        await _db.expenseByFeeling(range.start, range.end),
      ),
      topCategory: categories.isEmpty ? null : categories.first.name,
      topCategoryAmount: categories.isEmpty ? 0 : categories.first.total,
      biggest: biggest.isEmpty ? null : biggest.first,
    );
  }
}
