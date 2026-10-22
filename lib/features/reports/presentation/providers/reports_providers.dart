import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/reports/data/reports_repository.dart';
import 'package:hishab/features/reports/domain/category_branch.dart';
import 'package:hishab/features/reports/domain/period_totals.dart';
import 'package:hishab/features/reports/domain/report_data.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(ref.watch(appDatabaseProvider)),
);

/// The report for a period. The range is a record, which compares by value,
/// so asking for the same period twice shares one result. It is calculated
/// again after any change to the data.
final reportProvider = FutureProvider.autoDispose.family<ReportData, DateRange>(
  (ref, range) {
    ref.watch(dataChangesProvider);
    return ref.watch(reportsRepositoryProvider).loadReport(range);
  },
);

/// The twelve months of [year], oldest first, for the year view. It is
/// calculated again after any change to the data.
final yearMonthsProvider = FutureProvider.autoDispose
    .family<List<MonthTotals>, int>((ref, year) {
      ref.watch(dataChangesProvider);
      return ref
          .watch(reportsRepositoryProvider)
          .monthlyTotals(DateTime(year, 12), count: 12);
    });

/// What this month's money came to for every category, groups included: a
/// group's amount is its own money plus everything inside it. Expense and
/// income are in one map, since a category has only one type. It is calculated
/// again after any change to the data.
final categoryMonthTotalsProvider = FutureProvider.autoDispose<Map<int, int>>((
  ref,
) async {
  ref.watch(dataChangesProvider);
  final range = monthRange(ref.read(clockProvider)());
  final repository = ref.watch(reportsRepositoryProvider);
  final totals = <int, int>{};
  for (final type in [TransactionType.expense, TransactionType.income]) {
    for (final branch in flattenBranches(
      await repository.categoryBranches(range, type),
    )) {
      totals[branch.category.id] = branch.total;
    }
  }
  return totals;
});
